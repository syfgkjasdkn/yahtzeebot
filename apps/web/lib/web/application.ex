defmodule Web.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_type, _args) do
    port = Application.get_env(:web, :port) || raise("need web.port")

    children = [
      {Plug.Cowboy,
       scheme: :https,
       plug: Web.Router,
       options: [
         port: port,
         otp_app: :web,
         keyfile: "priv/server.key",
         certfile: "priv/server.pem"
       ]},
      {Task, fn -> maybe_set_webhook() end}
    ]

    opts = [strategy: :one_for_one, name: Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  def maybe_set_webhook do
    # TODO simplify
    if unquote(Mix.env() == :prod) do
      addr = addr!()
      port = :ranch.get_port(Web.Router.HTTPS) || raise("failed to get https port")
      url = "https://#{addr}:#{port}/tgbot"

      :ok =
        TGBot.set_webhook(
          url: url,
          certificate: Path.join(Application.app_dir(:web), "priv/server.pem")
        )

      Logger.info("set webhook to #{url}")
    end
  end

  defp addr! do
    {:ok, [{addr, _, _} | _rest]} = :inet.getif()

    addr
    |> :inet.ntoa()
    |> to_string()
  end
end
