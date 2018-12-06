defmodule Web.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    port = Application.get_env(:web, :port) || raise("need web.port")

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Web.Router,
        options: [port: port]
      )
    ]

    opts = [strategy: :one_for_one, name: Web.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
