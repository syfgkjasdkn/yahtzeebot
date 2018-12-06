use Mix.Config

config :tgbot, adapter: TGBot.NadiaAdapter

config :nadia,
  token: System.get_env("YAHTZEEBOT_DEV_TG_TOKEN") || raise("need YAHTZEEBOT_DEV_TG_TOKEN")
