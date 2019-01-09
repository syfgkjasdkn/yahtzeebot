defmodule UBot.PendingTips do
  @moduledoc false
  use GenServer

  @table __MODULE__

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def init(_opts) do
    @table = :ets.new(@table, [:named_table])
    {:ok, []}
  end

  def wait_for_update(message_id) do
    GenServer.call(__MODULE__, {:wait_for_update, message_id})
  end

  def updated(message_id) do
    GenServer.call(__MODULE__, {:updated, message_id})
  end

  def pending?(message_id) do
    case :ets.lookup(@table, message_id) do
      [{^message_id, _timestamp}] -> true
      [] -> false
    end
  end

  @doc false
  def handle_call({:wait_for_update, message_id}, _from, state) do
    {:reply, :ets.insert(@table, {message_id, :erlang.system_time(:second)}), state}
  end

  def handle_call({:updated, message_id}, _from, state) do
    {:reply, :ets.delete(@table, message_id), state}
  end
end
