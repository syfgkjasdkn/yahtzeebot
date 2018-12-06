defmodule TGBot.Adapter do
  @moduledoc false

  @typep telegram_id :: pos_integer

  @callback send_message(telegram_id, String.t()) :: any
  @callback send_message(telegram_id, String.t(), Keyword.t()) :: any

  @callback set_webhook(url :: String.t()) :: any

  @callback bot_id :: integer
end
