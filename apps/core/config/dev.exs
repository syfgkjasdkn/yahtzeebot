use Mix.Config

env! = fn var ->
  System.get_env(var) || raise("need #{var} set")
end

config :core,
  db_path: Path.expand("~/dbs/yahtzeebot.sqlite3"),
  tron_adapter: Core.Tron.TronAdapter,
  address: env!.("YAHTZEEBOT_TRON_ADDRESS"),
  owners_address: env!.("OWNERS_ADDRESS"),
  privkey: env!.("REWARDER_PRIVKEY"),
  tron_grpc_node_address: "35.180.51.163:50051"
