use Mix.Config

config :nadia, recv_timeout: 20

import_config "#{Mix.env()}.exs"
