defmodule UBot.Application do
  @moduledoc false
  use Application

  children =
    Enum.reject(
      [
        unless(Mix.env() == :test,
          do: {UBot, quote(do: _opts([:api_id, :api_hash, :phone_number, :bot_id]))}
        )
      ],
      &is_nil/1
    )

  def start(_type, _args) do
    children = unquote(children)
    opts = [strategy: :one_for_one, name: UBot.Supervisor]
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
