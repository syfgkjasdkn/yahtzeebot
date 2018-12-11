defmodule TGBot.NadiaAdapter do
  @behaviour TGBot.Adapter

  @impl true
  def send_message(telegram_id, text, opts \\ []) do
    Nadia.send_message(telegram_id, text, opts)
  end

  @impl true
  def set_webhook(opts) do
    Nadia.API.request("setWebhook", opts, :certificate)
  end

  @impl true
  def send_document(telegram_id, file_id, opts \\ []) do
    Nadia.send_document(telegram_id, file_id, opts)
  end

  @impl true
  def bot_id do
    {:ok, %Nadia.Model.User{id: bot_id}} = Nadia.get_me()

    bot_id
  end
end
