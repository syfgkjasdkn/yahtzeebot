defmodule Core.Tron.TronAdapter do
  @behaviour Core.Tron.Adapter
  require Logger

  @impl true
  def balance(<<address::21-bytes>>) do
    case Core.Tron.Pool.balance(address) do
      {:ok, %Tron.Account{balance: balance}} -> {:ok, balance}
      {:error, _} = error -> error
    end
  end

  @impl true
  def reward(to_address, amount) when is_integer(amount) do
    Core.Tron.transfer(
      amount * 1_000_000,
      to_address,
      Application.get_env(:core, :privkey)
    )
  end

  @impl true
  def send_transaction(%Tron.Transaction{} = transaction) do
    Core.Tron.Pool.broadcast_transaction(transaction)
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
    case Core.Tron.Pool.get_transaction_by_id(txid) do
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
