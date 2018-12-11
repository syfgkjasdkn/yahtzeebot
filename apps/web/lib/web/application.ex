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
      if public_ip = Application.get_env(:web, :public_ip) do
        port = :ranch.get_port(Web.Router.HTTPS) || raise("failed to get https port")
        url = "https://#{public_ip}:#{port}/tgbot"

        :ok =
          TGBot.set_webhook(
            url: url,
            certificate: Path.join(Application.app_dir(:web), "priv/server.pem")
          )

        Logger.info("set webhook to #{url}")
      else
        Logger.warn("couldn't find web.public_ip env var, skipping webhook setup")
      end
    end
  end
end
