defmodule Core.Tron.Adapter do
  @moduledoc false

  @callback balance(Tron.address()) :: {:ok, sun_amount :: integer} | {:error, reason :: any}
  @callback reward(Tron.address(), trx_amount :: pos_integer) :: {:ok, txid_base16 :: String.t()}
  @callback send_transaction(Tron.Transaction.t()) :: {:ok, String.t()}
  @callback lookup_transaction(<<_::256>>) :: Tron.Transaction.t() | nil
end
