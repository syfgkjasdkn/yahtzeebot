defmodule TGBot.TestAdapter do
  @moduledoc false
  @behaviour TGBot.Adapter

  @impl true
  def send_message(telegram_id, text, opts \\ []) do
    send(self(), {:message, telegram_id: telegram_id, text: text, opts: opts})
  end

  @impl true
  def send_document(telegram_id, file_id, opts \\ []) do
    send(self(), {:document, telegram_id: telegram_id, file_id: file_id, opts: opts})
  end

  @impl true
  def set_webhook(opts) do
    send(self(), {:webhook, opts})
  end

  @impl true
  def bot_id do
    123
  end
end
