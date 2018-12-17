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
       scheme: Application.get_env(:web, :scheme, :https),
       plug: Web.Router,
       options: [port: port] ++ Application.get_env(:web, :options, [])},
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
  @spec openssl(binary) :: binary
  def openssl(args) do
    :os.cmd('openssl #{args}')
  end

  @doc false
  @spec generate_certs(String.t()) :: {:ok, binary} | {:error, binary}
  def generate_certs(ip_address) do
    priv_dir = Application.app_dir(:web, "/priv")

    args = ~w[
      req -newkey rsa:2048 -sha256 -nodes
      -keyout #{Path.join(priv_dir, "server.key")}
      -x509 -days 365 -out #{Path.join(priv_dir, "server.pem")}
      -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=#{ip_address}"
    ]

    args
    |> Enum.join(" ")
    |> openssl()
  end
end
