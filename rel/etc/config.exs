use Mix.Config

env! = fn var, type ->
  val = System.get_env(var) || raise("need #{var} set")

  try do
    case type do
      :string ->
        val

      :integer ->
        String.to_integer(val)

      :float ->
        case Float.parse(val) do
          {val, ""} -> val
          _ -> raise(ArgumentError)
        end

      :ratio ->
        case :binary.split(val, "/") do
          [rolls, trx] -> {String.to_integer(rolls), String.to_integer(trx)}
          _ -> raise(ArgumentError)
        end

      {:list, :integer} ->
        val
        |> :binary.split(",", [:global, :trim])
        |> Enum.map(&String.to_integer/1)

      {:list, :string} ->
        :binary.split(val, ",", [:global, :trim])
    end
  rescue
    _error ->
      raise(ArgumentError, "couldn't parse #{inspect(val)} as #{type}")
  end
end

config :core,
  db_path: env!.("DB_PATH", :string),
  address: env!.("BOT_TRON_ADDRESS", :string),
  owners_address: env!.("OWNERS_ADDRESS", :string),
  privkey: env!.("REWARDER_PRIVKEY", :string),
  grpc_nodes: env!.("GRPC_NODES", {:list, :string}),
  winning_player_pct: env!.("WINNING_PLAYER_PCT", :float),
  house_pct: env!.("HOUSE_PCT", :float),
  rolls_to_trx_ratio: env!.("ROLLS_TO_TRX_RATIO", :ratio),
  reward_for_four_of_kind: env!.("REWARD_FOR_FOUR_OF_KIND", :integer),
  reward_for_large_straight: env!.("REWARD_FOR_LARGE_STRAIGHT", :integer),
  admin_ids: env!.("ADMIN_IDS", {:list, :integer})

config :web, port: env!.("WEB_PORT", :integer)

config :nadia, token: env!.("TG_BOT_TOKEN", :string)

config :ubot,
  api_id: env!.("TG_API_ID", :string),
  api_hash: env!.("TG_API_HASH", :string),
  phone_number: env!.("TG_PHONE_NUMBER", :string),
  tdlib_database_directory: env!.("TDLIB_DB_DIR", :string)

# TODO doesn't work dua to tdlib compiling the path, not reading it at runtime
config :tdlib, backend_binary: env!.("TDLIB_PATH", :string)
