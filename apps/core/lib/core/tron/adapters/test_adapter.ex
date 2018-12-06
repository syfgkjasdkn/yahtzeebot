defmodule Core.Tron.TestAdapter do
  @behaviour Core.Tron.Adapter

  @impl true
  def balance(_address) do
    {:ok, 1234}
  end

  @impl true
  def reward(address, amount) do
    send(test_process(), {:reward, address: address, amount: amount})
    {:ok, "tx87q32oiualfjbasdlkjfbasm"}
  end

  @impl true
  def send_transaction(transaction) do
    send(test_process(), transaction: transaction)
    :ok
  end

  # TODO use mox
  @impl true
  def lookup_transaction("trx" <> amount) do
    amount = String.to_integer(amount) * 1_000_000

    transfer_contract =
      Core.Tron.transfer_contract(
        :crypto.strong_rand_bytes(21),
        <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21>>,
        amount
      )

    transfer_contract
    |> Core.Tron.transaction_contract()
    |> Core.Tron.transaction(DateTime.to_unix(DateTime.utc_now(), :millisecond))
  end

  defp test_process do
    Application.get_env(:core, :shared_tron_test_process) ||
      raise("need :shared_tron_test_process")
  end
end
