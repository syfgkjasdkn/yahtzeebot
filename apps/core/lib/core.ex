defmodule Core do
  @moduledoc false
  require Logger
  alias Core.Games.Yahtzee

  defp try_reward(amount, to_address, attempts \\ 10)

  defp try_reward(amount, to_address, attempts) when attempts > 0 do
    case Core.Tron.reward(to_address, amount) do
      {:ok, _txid} = success ->
        success

      {:error, message} ->
        Logger.error("""
        failed to send a reward of: #{amount} TRX
        to address: #{Core.Base58.encode_check(to_address)}
        with message: #{inspect(message)}
        """)

        :timer.sleep(500 * attempts)

        try_reward(amount, to_address, attempts - 1)
    end
  end

  defp try_reward(_reward, _to_address, _attempts) do
    {:error, :give_up}
  end

  @spec roll(pos_integer) ::
          {:ok, Yahtzee.result(), txid :: String.t()}
          | {:ok, Yahtzee.result()}
          | {:error, :no_rolls | :give_up | any}
  def roll(telegram_id) do
    case Core.Session.roll(telegram_id) do
      {:ok, {:win, reward, _dice} = outcome} when reward in [:large_straight, :four_of_kind] ->
        case try_reward(reward_to_trx(reward), Core.Session.seedit_address(telegram_id)) do
          {:ok, txid} -> {:ok, outcome, txid}
          {:error, _reason} = failure -> failure
        end

      {:ok, {:win, :pool, _dice} = outcome} ->
        pool_size = pool_size()
        reward = :erlang.floor(pool_size * winning_player_pct())
        to_owners = :erlang.floor(pool_size * house_pct())

        try_reward(to_owners, owners_address!())

        case try_reward(reward, Core.Session.seedit_address(telegram_id)) do
          {:ok, txid} -> {:ok, outcome, txid}
          {:error, _reason} = failure -> failure
        end

      {:ok, _outcome} = no_trx_win ->
        no_trx_win

      {:error, :no_rolls} = no_rolls ->
        no_rolls
    end
  end

  defp reward_to_trx(:large_straight), do: reward_for_large_straight()
  defp reward_to_trx(:four_of_kind), do: reward_for_four_of_kind()

  @spec pool_size :: integer
  def pool_size do
    Storage.pool_size()
  end

  @spec process_tip(pos_integer, String.t()) ::
          {:ok, new_rolls_count :: non_neg_integer | :credited, pool_size :: integer}
          | {:error, :no_transfer | :invalid_contract}
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

  @spec rolls_to_trx_ratio :: {rolls :: pos_integer, trx :: pos_integer}
  def rolls_to_trx_ratio do
    Application.get_env(:core, :rolls_to_trx_ratio) ||
      raise("need core.rolls_to_trx_ratio to be set")
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

  @spec admin?(pos_integer) :: boolean
  def admin?(telegram_id) do
    telegram_id in Application.get_env(:core, :admin_ids)
  end

  def ensure_our_address!(%Tron.TransferContract{to_address: to_address}) do
    our_address = our_address!()
    our_address == to_address || raise("wrong address: expected #{our_address} got #{to_address}")
  end

  def process_transfer(
        %Tron.TransferContract{amount: amount, owner_address: tipper_address},
        tipper_id
      ) do
    :ok = Core.Session.set_seedit_address(tipper_id, tipper_address)
    :ok = Storage.change_pool_size(div(amount, 1_000_000))
    prev_credit = Core.Session.credit(tipper_id) * 1_000_000
    total_amount = prev_credit + amount

    {rolls, trx} = rolls_to_trx_ratio()

    case {div(total_amount, trx * 1_000_000) * rolls,
          div(rem(total_amount, trx * 1_000_000), 1_000_000)} do
      {0, new_credit} ->
        :ok = Core.Session.set_credit(tipper_id, new_credit)
        {:ok, :credited, pool_size()}

      {added_rolls, new_credit} ->
        :ok = Core.Session.set_credit(tipper_id, new_credit)
        {:ok, Core.Session.add_rolls(tipper_id, added_rolls), pool_size()}
    end
  end

  def process_transfer(%Tron.TransferAssetContract{}, _tipper_id) do
    {:error, :invalid_contract}
  end
end
