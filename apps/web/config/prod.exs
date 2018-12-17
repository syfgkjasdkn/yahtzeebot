use Mix.Config

# in prod we load config from system env (see rel/etc/config.exs)
config :web,
  options: [
    otp_app: :web,
    keyfile: "priv/server.key",
    certfile: "priv/server.pem"
  ]
