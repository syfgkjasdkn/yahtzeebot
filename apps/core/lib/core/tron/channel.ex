defmodule Core.Tron.Channel do
  @moduledoc false
  use GenServer
  require Logger

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def init(_opts) do
    send(self(), :connect)
    {:ok, nil}
  end

  @spec balance(pid, Tron.address()) :: {:ok, integer} | {:error, any}
  def balance(pid, <<address::21-bytes>>) do
    GenServer.call(pid, {:balance, address}, :infinity)
  end

  def get_now_block(pid) do
    GenServer.call(pid, :get_now_block, :infinity)
  end

  def get_transaction_by_id(pid, <<txid::32-bytes>>) do
    GenServer.call(pid, {:get_transaction_by_id, txid}, :infinity)
  end

  def broadcast_transaction(pid, transaction) do
    GenServer.call(pid, {:broadcast_transaction, transaction}, :infinity)
  end

  @doc false
  def handle_info(:connect, nil) do
    nodes = Application.get_env(:core, :grpc_nodes)
    {:ok, channel} = try_connect(nodes)
    {:noreply, channel}
  end

  def handle_info({:gun_down, _pid, :http2, reason, _, _}, channel)
      when reason in [:closed, :normal] do
    {:noreply, channel}
  end

  def handle_info({:gun_up, _pid, :http2}, channel) do
    {:noreply, channel}
  end

  @doc false
  def handle_call({:balance, address}, _from, channel) do
    {:reply, Tron.Client.get_account(channel, Tron.Account.new(address: address)), channel}
  end

  def handle_call(:get_now_block, _from, channel) do
    {:reply, Tron.Client.get_now_block2(channel, Tron.EmptyMessage.new()), channel}
  end

  def handle_call({:get_transaction_by_id, txid}, _from, channel) do
    reply =
      Tron.Client.get_transaction_by_id(channel, Google.Protobuf.BytesValue.new(value: txid))

    {:reply, reply, channel}
  end

  def handle_call({:broadcast_transaction, transaction}, _from, channel) do
    {:reply, Tron.Client.broadcast_transaction(channel, transaction), channel}
  end

  @spec try_connect([String.t()], non_neg_integer) :: {:ok, GRPC.Channel.t()}
  defp try_connect(nodes, attempts \\ 10)

  defp try_connect(nodes, attempts) when attempts > 0 do
    node_address = Enum.random(nodes)

    case GRPC.Stub.connect(node_address) do
      {:ok, _channel} = success ->
        success

      failure ->
        Logger.error("failied to connect to #{node_address}:\n\n#{inspect(failure)}")
        try_connect(nodes, attempts - 1)
    end
  end
end
