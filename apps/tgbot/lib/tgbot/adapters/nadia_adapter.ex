defmodule TGBot.NadiaAdapter do
  @behaviour TGBot.Adapter

  @impl true
  def send_message(telegram_id, text, opts \\ []) do
    Nadia.send_message(telegram_id, text, opts)
  end

  @impl true
  def set_webhook(url) do
    Nadia.set_webhook(url: url)
  end

  @impl true
  def bot_id do
    {:ok, %Nadia.Model.User{id: bot_id}} = Nadia.get_me()

    bot_id
  end
end
