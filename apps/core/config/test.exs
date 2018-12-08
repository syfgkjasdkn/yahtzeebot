use Mix.Config

config :core,
  tron_adapter: Core.Tron.TestAdapter,
  owners_address: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21>>,
  address: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21>>,
  winning_player_pct: 0.8,
  house_pct: 0.1,
  rolls_to_trx_ratio: {3, 100},
  reward_for_four_of_kind: 400,
  reward_for_large_straight: 200,
  grpc_nodes: ["35.180.51.163:50051"]
