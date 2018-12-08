defmodule Core.Tron do
  @moduledoc """
  Some helper functions to interact with TRON
  """

  require Logger
  require Record
  Record.defrecordp(:state, [:channel, :privkey])

  @typep state :: record(:state, channel: GRPC.Channel.t(), privkey: Tron.privkey())

  @adapter Application.get_env(:core, :tron_adapter) || raise("need core.tron_adapter")

  def adapter do
    @adapter
  end

  # TODO maybe use a pool of channels instead of a single genserver
  # revisit if any bottlenecks start to appear
  use GenServer

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @spec init(Keyword.t()) :: {:ok, state}
  def init(opts) do
    privkey = opts[:privkey] || raise("need :privkey")

    # check here so that it doesn't fail in handle_info
    Application.get_env(:core, :grpc_nodes) || raise("need core.grpc_nodes")

    send(self(), :connect)
    {:ok, state(privkey: privkey)}
  end

  @doc "Fetch current balance for an address"
  @spec balance(Tron.address()) ::
          {:ok, %{(asset_name :: String.t()) => amount :: integer}} | {:error, reason :: any}
  def balance(<<address::21-bytes>>) do
    @adapter.balance(address)
  end

  @doc """
  Fetch transaction info by its id.

  Blocks the executing process.
  """
  @spec lookup_transaction(<<_::256>>) :: Tron.Transaction.t() | nil
  def lookup_transaction(txid) do
    @adapter.lookup_transaction(txid)
  end

  @spec extract_transfer(Tron.Transaction.t()) ::
          Tron.TransferAssetContract.t() | Tron.TransferContract.t()
  def extract_transfer(%Tron.Transaction{
        raw_data: %Tron.Transaction.Raw{
          contract: [
            %Tron.Transaction.Contract{
              parameter: %Google.Protobuf.Any{type_url: type_url, value: value},
              # TODO use this one
              type: _type
            }
          ]
        }
      }) do
    # TODO find another way
    case type_url do
      "type.googleapis.com/protocol.TransferAssetContract" ->
        Tron.TransferAssetContract.decode(value)

      "type.googleapis.com/protocol.TransferContract" ->
        Tron.TransferContract.decode(value)
    end
  end

  @spec latest_block :: Tron.BlockExtention.t()
  def latest_block do
    channel()
    |> Tron.Client.get_now_block2(Tron.EmptyMessage.new())
    |> case do
      # TODO can it fail?
      {:ok,
       %Tron.BlockExtention{
         block_header: %Tron.BlockHeader{raw_data: %Tron.BlockHeader.Raw{}}
       } = block_extension} ->
        block_extension
    end
  end

  @doc false
  @spec transaction(Tron.Transaction.Contract.t(), pos_integer) :: Tron.Transaction.t()
  def transaction(contract, timestamp) do
    Tron.Transaction.new(
      raw_data: Tron.Transaction.Raw.new(contract: [contract], timestamp: timestamp),
      signature: []
    )
  end

  @doc false
  @spec transfer_contract(binary, binary, pos_integer) :: Tron.TransferContract.t()
  def transfer_contract(<<from::21-bytes>>, <<to::21-bytes>>, amount) do
    Tron.TransferContract.new(
      owner_address: from,
      to_address: to,
      amount: amount
    )
  end

  @doc false
  @spec transaction_contract(Tron.TransferContract.t()) :: Tron.Transaction.Contract.t()
  def transaction_contract(%Tron.TransferContract{} = contract) do
    Tron.Transaction.Contract.new(
      type: 1,
      parameter:
        Google.Protobuf.Any.new(
          value: Tron.TransferContract.encode(contract),
          type_url: "type.googleapis.com/protocol.TransferContract"
        )
    )
  end

  def transfer_transaction(<<from::21-bytes>>, <<to::21-bytes>>, amount) do
    transfer_contract = transfer_contract(from, to, amount)

    transfer_contract
    |> transaction_contract()
    |> transaction(timestamp())
  end

  defp timestamp do
    DateTime.to_unix(DateTime.utc_now(), :millisecond)
  end

  @spec reward(Tron.address(), pos_integer) :: {:ok, txid_base16 :: String.t()}
  def reward(<<to_address::21-bytes>>, amount) do
    @adapter.reward(to_address, amount)
  end

  @spec transfer(pos_integer, Tron.address(), Tron.privkey()) :: {:ok, txid_base16 :: String.t()}
  def transfer(amount, <<to_address::21-bytes>>, <<privkey::32-bytes>>) do
    %Tron.BlockExtention{
      block_header: %Tron.BlockHeader{
        raw_data: %Tron.BlockHeader.Raw{} = block_header_raw
      }
    } = latest_block()

    from_address = Tron.address(privkey)

    transfer_transaction = transfer_transaction(from_address, to_address, amount)

    signed_transaction =
      transfer_transaction
      |> Tron.set_reference(block_header_raw)
      |> Tron.sign_transaction(privkey)

    channel()
    |> Tron.Client.broadcast_transaction(signed_transaction)
    |> case do
      {:ok, %Tron.Return{code: 0, result: true}} ->
        {:ok, txid_base16(signed_transaction)}

      {:ok, %Tron.Return{message: message, result: false}} ->
        {:error, message}
    end
  end

  def txid_base16(%Tron.Transaction{raw_data: raw_data}) do
    :sha256
    |> :crypto.hash(Tron.Transaction.Raw.encode(raw_data))
    |> Base.encode16(case: :lower)
  end

  def tronscan_transaction_link(txid_base16) do
    "https://tronscan.org/#/transaction/#{txid_base16}"
  end

  @doc false
  @spec channel :: GRPC.Channel.t()
  def channel do
    GenServer.call(__MODULE__, :channel)
  end

  # TODO do this in the server process or trnasfer the ownership
  @spec reconnect_to_address(String.t()) :: {:ok, GRPC.Channel.t()} | {:error, any}
  def reconnect_to_address(address) do
    case GRPC.Stub.connect(address) do
      {:ok, channel} = reply ->
        :ok = GenServer.call(__MODULE__, {:set_channel, channel})
        reply

      {:error, _} = error ->
        error
    end
  end

  @doc false
  @spec privkey :: Tron.private_key()
  def privkey do
    GenServer.call(__MODULE__, :privkey)
  end

  @doc false
  def handle_call(message, from, state)

  @spec handle_call(:channel, GenServer.from(), state) :: {:reply, GRPC.Channel.t(), state}
  def handle_call(:channel, _from, state(channel: channel) = state) do
    {:reply, channel, state}
  end

  @spec handle_call(:privkey, GenServer.from(), state) :: {:reply, Tron.private_key(), state}
  def handle_call(:privkey, _from, state(privkey: privkey) = state) do
    {:reply, privkey, state}
  end

  def handle_call({:set_channel, channel}, _from, state) do
    {:reply, :ok, state(state, channel: channel)}
  end

  @doc false
  def handle_info(message, state)

  @spec handle_info(:connect, state) :: {:noreply, state}
  def handle_info(:connect, state) do
    nodes = Application.get_env(:core, :grpc_nodes) || raise("need core.grpc_nodes")
    {:ok, channel} = try_connect(nodes)
    {:noreply, state(state, channel: channel)}
  end

  def handle_info({:gun_down, _pid, :http2, reason, _, _}, state)
      when reason in [:closed, :normal] do
    {:noreply, state}
  end

  def handle_info({:gun_up, _pid, :http2}, state) do
    {:noreply, state}
  end

  defp try_connect([node_address | rest]) do
    case GRPC.Stub.connect(node_address) do
      {:ok, _channel} = success ->
        success

      failure ->
        Logger.error("failied to connect to #{node_address}:\n\n#{inspect(failure)}")
        try_connect(rest)
    end
  end
end
