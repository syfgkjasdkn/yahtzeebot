defmodule Web.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_type, _args) do
    port = Application.get_env(:web, :port) || raise("need web.port")

    if unquote(Mix.env() == :prod) do
      if public_ip = Application.get_env(:web, :public_ip) do
        generate_certs(public_ip)
      end
    end

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

  @doc false
  def openssl(args) do
    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, 1} -> {:error, error}
    end
  end

  @doc false
  @spec generate_certs(String.t()) :: {:ok, binary} | {:error, binary}
  def generate_certs(ip_address) do
    priv_dir = Application.app_dir(:web, "/priv")
    openssl(~w[
        req -newkey rsa:2048 -sha256 -nodes -keyout #{Path.join(priv_dir, "server.key")}
        -x509 -days 365 -out #{Path.join(priv_dir, "server.pem")}
        -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=#{ip_address}"
      ])
  end
end
