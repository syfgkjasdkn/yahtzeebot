defmodule Core do
  @moduledoc false
  require Logger
  alias Core.Games.Yahtzee

  defp try_reward(token, amount, to_address, attempts \\ 10, wait \\ 500)

  defp try_reward(token, amount, to_address, attempts, wait) when attempts > 0 do
    case Core.Tron.reward(token, to_address, amount) do
      {:ok, _txid} = success ->
        success

      {:error, message} ->
        Logger.error("""
        failed to send a reward of: #{amount} #{token}
        to address: #{Core.Base58.encode_check(to_address)}
        with message: #{inspect(message)}
        """)

        :timer.sleep(wait)

        try_reward(token, amount, to_address, attempts - 1, wait + 500)
    end
  end

  defp try_reward(_token, _reward, _to_address, _attempts, _wait) do
    {:error, :give_up}
  end

  @spec roll(pos_integer) ::
          {:ok, Yahtzee.result(), txid :: String.t()}
          | {:ok, Yahtzee.result()}
          | {:error, :no_rolls | :give_up | any}
  def roll(telegram_id) do
    case Core.Session.roll(telegram_id) do
      {:ok, {:win, reward, _dice} = outcome} when reward in [:large_straight, :four_of_kind] ->
        reward_amount = reward_to_token(reward)

        case try_reward(token(), reward_amount, Core.Session.seedit_address(telegram_id)) do
          {:ok, txid} ->
            :ok = Storage.change_pool_size(-reward_amount)
            {:ok, outcome, txid}

          {:error, _reason} = failure ->
            failure
        end

      {:ok, {:win, :pool, _dice} = outcome} ->
        pool_size = pool_size()
        reward = :erlang.floor(pool_size * winning_player_pct())
        to_owners = :erlang.floor(pool_size * house_pct())

        case try_reward(token(), to_owners, owners_address!()) do
          {:ok, _txid} ->
            :ok = Storage.change_pool_size(-to_owners)

          _ ->
            nil
        end

        case try_reward(token(), reward, Core.Session.seedit_address(telegram_id)) do
          {:ok, txid} ->
            :ok = Storage.change_pool_size(-reward)
            {:ok, outcome, txid}

          {:error, _reason} = failure ->
            failure
        end

      {:ok, _outcome} = no_token_win ->
        no_token_win

      {:error, :no_rolls} = no_rolls ->
        no_rolls
    end
  end

  defp reward_to_token(:large_straight), do: reward_for_large_straight()
  defp reward_to_token(:four_of_kind), do: reward_for_four_of_kind()

  @spec pool_size :: integer
  def pool_size do
    Storage.pool_size()
  end

  @spec process_tip(pos_integer, String.t()) ::
          {:ok, new_rolls_count :: non_neg_integer | :credited, pool_size :: integer}
          | {:error, :no_transfer | :invalid_contract | :invalid_token}
  def process_tip(tipper_id, txid) do
    txid
    |> Base.decode16!(case: :mixed)
    |> Core.Tron.lookup_transaction()
    |> Core.Tron.extract_transfer()
    |> case do
      transfer_contract when not is_nil(transfer_contract) ->
        # TODO don't raise
        ensure_our_address!(transfer_contract)
        process_transfer(transfer_contract, tipper_id)

      _ ->
        {:error, :no_transfer}
    end
  end

  def our_address! do
    Application.get_env(:core, :address) || raise("need core.address to be set")
  end

  def owners_address! do
    Application.get_env(:core, :owners_address) || raise("need core.owners_address to be set")
  end

  def current_node! do
    Application.get_env(:core, :tron_grpc_node_address) ||
      raise("need core.tron_grpc_node_address to be set")
  end

  @spec winning_player_pct :: float
  def winning_player_pct do
    Application.get_env(:core, :winning_player_pct) ||
      raise("need core.winning_player_pct to be set")
  end

  @spec house_pct :: float
  def house_pct do
    Application.get_env(:core, :house_pct) || raise("need core.house_pct to be set")
  end

  @spec rolls_to_token_ratio :: {rolls :: pos_integer, tokens :: pos_integer}
  def rolls_to_token_ratio do
    Application.get_env(:core, :rolls_to_token_ratio) ||
      raise("need core.rolls_to_token_ratio to be set")
  end

  @spec reward_for_large_straight :: trx :: pos_integer
  def reward_for_four_of_kind do
    Application.get_env(:core, :reward_for_four_of_kind) ||
      raise("need core.reward_for_four_of_kind to be set")
  end

  @spec reward_for_large_straight :: trx :: pos_integer
  def reward_for_large_straight do
    Application.get_env(:core, :reward_for_large_straight) ||
      raise("need core.reward_for_large_straight to be set")
  end

  @spec roll_outcome_file_id :: String.t() | nil
  def roll_outcome_file_id do
    bot_id = Application.get_env(:nadia, :token)
    Storage.roll_pic_file_id(bot_id)
  end

  @spec set_roll_outcome_file_id(String.t()) :: :ok
  def set_roll_outcome_file_id(file_id) do
    bot_id = Application.get_env(:nadia, :token)
    Storage.set_roll_pic(bot_id, file_id)
  end

  @spec pool_size_cap :: pos_integer
  def pool_size_cap do
    Application.get_env(:core, :pool_size_cap) || raise("need core.pool_size_cap to be set")
  end

  @spec auth_tdlib(String.t()) :: any
  def auth_tdlib(code) do
    {mod, fun, args} =
      Application.get_env(:core, :auth_tdlib_mfa) || raise("need core.auth_tdlib_mfa")

    apply(mod, fun, [code | args])
  end

  @spec admin?(pos_integer) :: boolean
  def admin?(telegram_id) do
    telegram_id in Application.get_env(:core, :admin_ids)
  end

  @spec initialize_room(integer) :: :ok | {:error, any}
  def initialize_room(room_id) when is_integer(room_id) do
    phone_number = Application.get_env(:ubot, :phone_number) || raise("need ubot.phone_number")

    case Storage.insert_initialized_room(phone_number, room_id) do
      :ok ->
        initialize_rooms = Storage.initialized_rooms(phone_number)
        :ok = Application.put_env(:ubot, :tracked_chat_ids, initialize_rooms)
        :ok

      other ->
        other
    end
  end

  @spec deinitialize_room(integer) :: :ok
  def deinitialize_room(room_id) when is_integer(room_id) do
    phone_number = Application.get_env(:ubot, :phone_number) || raise("need ubot.phone_number")
    :ok = Storage.delete_initialized_room(phone_number, room_id)
    initialize_rooms = Storage.initialized_rooms(phone_number)
    :ok = Application.put_env(:ubot, :tracked_chat_ids, initialize_rooms)
    :ok
  end

  @spec token :: String.t()
  def token do
    Application.get_env(:core, :token, "TRX")
  end

  @spec ensure_our_address!(Tron.TransferContract.t() | Tron.TransferAssetContract.t()) ::
          true | no_return
  def ensure_our_address!(%{to_address: to_address}) do
    our_address = our_address!()
    our_address == to_address || raise("wrong address: expected #{our_address} got #{to_address}")
  end

  def process_transfer(
        %Tron.TransferContract{amount: amount, owner_address: tipper_address},
        tipper_id
      ) do
    :ok = Core.Session.set_seedit_address(tipper_id, tipper_address)

    if token() == "TRX" do
      pool_size_change = div(amount, 1_000_000)
      pool_size = Storage.pool_size()

      :ok =
        cond do
          pool_size + pool_size_change < pool_size_cap() ->
            Storage.change_pool_size(pool_size_change)

          pool_size + pool_size_change == pool_size_cap() ->
            :ok

          true ->
            Storage.change_pool_size(pool_size_cap() - pool_size)
        end

      prev_credit = Core.Session.credit(tipper_id) * 1_000_000
      total_amount = prev_credit + amount

      {rolls, trx} = rolls_to_token_ratio()

      case {div(total_amount, trx * 1_000_000) * rolls,
            div(rem(total_amount, trx * 1_000_000), 1_000_000)} do
        {0, new_credit} ->
          :ok = Core.Session.set_credit(tipper_id, new_credit)
          {:ok, :credited, pool_size()}

        {added_rolls, new_credit} ->
          :ok = Core.Session.set_credit(tipper_id, new_credit)
          {:ok, Core.Session.add_rolls(tipper_id, added_rolls), pool_size()}
      end
    else
      {:error, :invalid_token}
    end
  end

  def process_transfer(
        %Tron.TransferAssetContract{
          asset_name: asset_name,
          amount: amount,
          owner_address: tipper_address
        },
        tipper_id
      ) do
    :ok = Core.Session.set_seedit_address(tipper_id, tipper_address)

    if token() == asset_name do
      pool_size_change = amount
      pool_size = Storage.pool_size()

      :ok =
        cond do
          pool_size + pool_size_change < pool_size_cap() ->
            Storage.change_pool_size(pool_size_change)

          pool_size + pool_size_change == pool_size_cap() ->
            :ok

          true ->
            Storage.change_pool_size(pool_size_cap() - pool_size)
        end

      prev_credit = Core.Session.credit(tipper_id)
      total_amount = prev_credit + amount

      {rolls, tokens} = rolls_to_token_ratio()

      case {div(total_amount, tokens) * rolls, rem(total_amount, tokens)} do
        {0, new_credit} ->
          :ok = Core.Session.set_credit(tipper_id, new_credit)
          {:ok, :credited, pool_size()}

        {added_rolls, new_credit} ->
          :ok = Core.Session.set_credit(tipper_id, new_credit)
          {:ok, Core.Session.add_rolls(tipper_id, added_rolls), pool_size()}
      end
    else
      {:error, :invalid_token}
    end
  end
end
