use Mix.Config

config :core,
  tron_adapter: Core.Tron.TronAdapter,
  ensure_loaded_env?: true,
  start_tron_pool?: true
