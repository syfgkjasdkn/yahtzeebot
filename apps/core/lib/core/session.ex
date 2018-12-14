defmodule Core.Session do
  @moduledoc false
  use GenServer, restart: :transient
  alias Core.Games.Yahtzee

  require Logger
  require Record

  # 10 minutes
  @timeout 10 * 60 * 1000

  # TODO add address here to avoid read from sqlite every time
  Record.defrecord(:state, [:telegram_id, rolls_left: 0, timeout: @timeout])

  @typep state ::
           record(:state,
             telegram_id: pos_integer,
             rolls_left: non_neg_integer,
             timeout: timeout
           )

  @doc false
  def start_link(opts) do
    telegram_id = opts[:telegram_id] || raise("need telegram id")
    GenServer.start_link(__MODULE__, opts, name: via(telegram_id))
  end

  @doc false
  def via(telegram_id) when is_integer(telegram_id) do
    {:via, Registry, {Core.Session.Registry, telegram_id}}
  end

  @spec add_rolls(pos_integer, pos_integer) :: new_rolls_count :: pos_integer
  def add_rolls(telegram_id, count) when is_integer(count) and count > 0 do
    call(telegram_id, {:add_rolls, count})
  end

  @spec roll(pos_integer) :: {:ok, Yahtzee.result()} | {:error, :no_rolls}
  def roll(telegram_id) do
    call(telegram_id, :roll)
  end

  @spec rolls_left(pos_integer) :: non_neg_integer
  def rolls_left(telegram_id) do
    call(telegram_id, :rolls_left)
  end

  @spec credit(pos_integer) :: non_neg_integer
  def credit(telegram_id) do
    call(telegram_id, :credit)
  end

  @spec set_credit(pos_integer, non_neg_integer) :: :ok
  def set_credit(telegram_id, credit) do
    call(telegram_id, {:set_credit, credit})
  end

  # TODO buy rolls (tip + credit)

  @spec seedit_address(pos_integer) :: Tron.address() | nil
  def seedit_address(telegram_id) do
    call(telegram_id, :seedit_address)
  end

  @spec set_seedit_address(pos_integer, Tron.address()) :: :ok
  def set_seedit_address(telegram_id, <<address::21-bytes>>) do
    call(telegram_id, {:set_seedit_address, address})
  end

  defp call(telegram_id, message) when is_integer(telegram_id) do
    GenServer.call(via(telegram_id), message)
  catch
    :exit, {:noproc, _} ->
      _ = Core.Session.Supervisor.start_session(telegram_id)
      call(telegram_id, message)
  end

  @doc false
  @spec init(Keyword.t()) :: {:ok, state}
  def init(opts) do
    send(self(), :init)
    {:ok, state(telegram_id: opts[:telegram_id])}
  end

  @doc false
  def handle_call(message, from, state)

  def handle_call({:add_rolls, count}, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    :ok = Storage.change_rolls_count(telegram_id, count)
    %Storage.User{rolls_left: rolls_left} = Storage.user(telegram_id)
    {:reply, rolls_left, state(state, rolls_left: rolls_left), timeout}
  end

  def handle_call(:roll, _from, state(rolls_left: rolls_left, timeout: timeout) = state)
      when rolls_left < 1 do
    {:reply, {:error, :no_rolls}, state, timeout}
  end

  def handle_call(:roll, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    :ok = Storage.change_rolls_count(telegram_id, -1)
    %Storage.User{rolls_left: rolls_left} = Storage.user(telegram_id)

    {outcome, state} =
      case Yahtzee.play() do
        {:win, :extra_roll, _dice} = outcome ->
          :ok = Storage.change_rolls_count(telegram_id, +1)
          {outcome, state(state, rolls_left: rolls_left + 1)}

        outcome ->
          {outcome, state(state, rolls_left: rolls_left)}
      end

    {:reply, {:ok, outcome}, state, timeout}
  end

  def handle_call(:seedit_address, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    %Storage.User{seedit_address: seedit_address} = Storage.user(telegram_id)
    {:reply, seedit_address, state, timeout}
  end

  def handle_call(:rolls_left, _from, state(rolls_left: rolls_left, timeout: timeout) = state) do
    {:reply, rolls_left, state, timeout}
  end

  def handle_call(:credit, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    %Storage.User{credit: credit} = Storage.user(telegram_id)
    {:reply, credit, state, timeout}
  end

  def handle_call({:set_credit, credit}, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    :ok = Storage.set_credit(telegram_id, credit)
    {:reply, :ok, state, timeout}
  end

  def handle_call({:set_seedit_address, address}, _from, state) do
    state(telegram_id: telegram_id, timeout: timeout) = state
    :ok = Storage.set_seedit_address(telegram_id, address)
    {:reply, :ok, state, timeout}
  end

  @doc false
  def handle_info(message, state)

  def handle_info(:init, state(timeout: timeout, telegram_id: telegram_id) = state) do
    :ok = Storage.ensure_user_exists(telegram_id)
    %Storage.User{rolls_left: rolls_left} = Storage.user(telegram_id)
    {:noreply, state(state, rolls_left: rolls_left), timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
