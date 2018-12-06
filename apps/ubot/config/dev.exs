use Mix.Config

config :ubot,
  api_id: System.get_env("TG_API_ID") || raise("need TG_API_ID"),
  api_hash: System.get_env("TG_API_HASH") || raise("need TG_API_HASH"),
  phone_number: System.get_env("TG_PHONE_NUMBER") || raise("need TG_PHONE_NUMBER")
