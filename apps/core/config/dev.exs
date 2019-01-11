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
  grpc_nodes: ["34.253.187.192:50051", "54.252.224.209:50051"],
  winning_player_pct: 0.8,
  house_pct: 0.1,
  rolls_to_token_ratio: {3, 100},
  reward_for_four_of_kind: 400,
  reward_for_large_straight: 200,
  admin_ids: [113_011],
  pool_size_cap: 1_000_000,
  start_tron_pool?: true,
  ensure_loaded_env?: true
