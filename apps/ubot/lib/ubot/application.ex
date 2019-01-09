defmodule UBot.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    config = Application.get_all_env(:ubot)

    maybe_children = [
      if config[:start_ubot?] do
        {UBot, _opts([:api_id, :api_hash, :phone_number, :bot_id, :tdlib_database_directory])}
      end
    ]

    children = Enum.reject(maybe_children, &is_nil/1)

    opts = [strategy: :one_for_one, name: UBot.Supervisor]
    Application.put_env(:core, :auth_tdlib_mfa, {UBot, :auth, []})

    if config[:load_tracked_chat_ids?] do
      Application.put_env(
        :ubot,
        :tracked_chat_ids,
        Storage.initialized_rooms(config[:phone_number] || raise("need ubot.phone_number"))
      )
    end

    Supervisor.start_link(children, opts)
  end

  @doc false
  def _opts(keys) do
    Enum.map(keys, fn key -> {key, _get(key)} end)
  end

  @doc false
  def _get(:bot_id) do
    TGBot.bot_id()
  end

  @doc false
  def _get(key) do
    Application.get_env(:ubot, key)
  end
end
