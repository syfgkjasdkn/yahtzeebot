defmodule Core.Tron.TronAdapter do
  @behaviour Core.Tron.Adapter
  require Logger

  @impl true
  def balance(<<address::21-bytes>>) do
    Core.Tron.channel()
    |> Tron.Client.get_account(Tron.Account.new(address: address))
    |> case do
      {:ok, %Tron.Account{balance: balance}} -> {:ok, balance}
      {:error, _} = error -> error
    end
  end

  @impl true
  def reward(to_address, amount) when is_integer(amount) do
    Core.Tron.transfer(
      amount * 1_000_000,
      to_address,
      Core.Tron.privkey()
    )
  end

  @impl true
  def send_transaction(%Tron.Transaction{} = transaction) do
    Tron.Client.broadcast_transaction(Core.Tron.channel(), transaction)
  end

  @impl true
  def lookup_transaction(txid) do
    _lookup_transaction(txid)
  end

  @doc false
  def _lookup_transaction(txid, attempts \\ 30, wait \\ 300)

  def _lookup_transaction(txid, 0, _wait) do
    Logger.error("failed to lookup transaction #{inspect(txid)} after 30 attempts")
    nil
  end

  def _lookup_transaction(<<txid::32-bytes>>, attempts, wait) do
    Core.Tron.channel()
    |> Tron.Client.get_transaction_by_id(Google.Protobuf.BytesValue.new(value: txid))
    |> case do
      {:ok, %Tron.Transaction{raw_data: nil, ret: [], signature: []}} ->
        :timer.sleep(wait)
        _lookup_transaction(txid, attempts - 1, wait + 100)

      {:error, error} ->
        Logger.error("error when fetching trnasaction:\n\n#{inspect(error)}")
        :timer.sleep(wait)
        _lookup_transaction(txid, attempts - 1, wait + 100)

      {:ok, %Tron.Transaction{} = transaction} ->
        transaction
    end
  end
end
