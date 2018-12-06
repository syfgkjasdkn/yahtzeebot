use Mix.Config

env! = fn var, type ->
  val = System.get_env(var) || raise("need #{var} set")

  try do
    case type do
      :string -> val
      :integer -> String.to_integer(val)
    end
  rescue
    _error ->
      raise(ArgumentError, "couldn't parse #{val} as #{type}")
  end
end

config :core,
  db_path: env!.("DB_PATH", :string),
  address: env!.("BOT_TRON_ADDRESS", :string),
  owners_address: env!.("OWNERS_ADDRESS", :string),
  privkey: env!.("REWARDER_PRIVKEY", :string),
  tron_grpc_node_address: env!.("TRON_GRPC_NODE_ADDRESS", :string)

config :web, port: env!.("WEB_PORT", :integer)

config :nadia, token: env!.("TG_BOT_TOKEN", :string)

config :ubot,
  api_id: env!.("TG_API_ID", :string),
  api_hash: env!.("TG_API_HASH", :string),
  phone_number: env!.("TG_PHONE_NUMBER", :stirng)

config :tdlib, backend_binary: env!.("TDLIB_PATH", :string)
