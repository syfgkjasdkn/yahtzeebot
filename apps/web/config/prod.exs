use Mix.Config

# in prod we load config from system env (see rel/etc/config.exs)
config :web,
  generate_certs?: true,
  set_webhook?: true,
  options: [
    otp_app: :web,
    keyfile: "priv/server.key",
    certfile: "priv/server.pem"
  ]
