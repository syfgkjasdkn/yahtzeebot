defmodule TGBot.Adapter do
  @moduledoc false

  @typep telegram_id :: pos_integer

  @callback send_message(telegram_id, String.t()) :: any
  @callback send_message(telegram_id, String.t(), Keyword.t()) :: any

  @callback send_document(telegram_id, String.t()) :: any
  @callback send_document(telegram_id, String.t(), Keyword.t()) :: any

  @callback set_webhook(Keyword.t()) :: any

  @callback bot_id :: integer
end
