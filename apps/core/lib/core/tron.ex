defmodule Core.Tron do
  @moduledoc """
  Some helper functions to interact with TRON
  """
  require Logger

  @adapter Application.get_env(:core, :tron_adapter) || raise("need core.tron_adapter")

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
    case Core.Tron.Pool.get_now_block() do
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

    signed_transaction =
      transfer_transaction(from_address, to_address, amount)
      |> Tron.set_reference(block_header_raw)
      |> Tron.sign_transaction(privkey)

    case Core.Tron.Pool.broadcast_transaction(signed_transaction) do
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
end
