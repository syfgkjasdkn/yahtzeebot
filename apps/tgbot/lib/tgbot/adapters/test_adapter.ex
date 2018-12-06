defmodule TGBot.TestAdapter do
  @moduledoc false
  @behaviour TGBot.Adapter

  @impl true
  def send_message(telegram_id, text, opts \\ []) do
    send(self(), {:message, telegram_id: telegram_id, text: text, opts: opts})
  end

  @impl true
  def set_webhook(url) do
    send(self(), {:webhook, url: url})
  end

  @impl true
  def bot_id do
    123
  end
end
