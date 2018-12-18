defmodule Core.Tron.Pool do
  @moduledoc false

  def broadcast_transaction(%Tron.Transaction{} = transaction) do
    :poolboy.transaction(__MODULE__, fn pid ->
      Core.Tron.Channel.broadcast_transaction(pid, transaction)
    end)
  end

  def get_now_block do
    :poolboy.transaction(__MODULE__, fn pid ->
      Core.Tron.Channel.get_now_block(pid)
    end)
  end

  def get_transaction_by_id(<<txid::32-bytes>>) do
    :poolboy.transaction(__MODULE__, fn pid ->
      Core.Tron.Channel.get_transaction_by_id(pid, txid)
    end)
  end

  def balance(<<address::21-bytes>>) do
    :poolboy.transaction(__MODULE__, fn pid ->
      Core.Tron.Channel.balance(pid, address)
    end)
  end
end
