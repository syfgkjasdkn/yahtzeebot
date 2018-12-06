use Mix.Config

config :logger, level: :info

config :ubot, tracked_chat_ids: []

import_config "#{Mix.env()}.exs"
