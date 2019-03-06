defmodule Storage do
  @moduledoc false

  use GenServer
  alias Storage.User

  require Record
  Record.defrecordp(:state, [:conn, :statements])

  @typep connection :: {:connection, reference(), term()}

  @typep statement :: {:statement, term(), connection()}

  @typep sql :: iodata

  @typep statements :: %{sql() => statement()}
  @typep state ::
           record(:state,
             conn: connection(),
             statements: statements
           )

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc false
  def init(opts) do
    path = opts[:path] || raise("need path for the database")

    conn =
      case :esqlite3.open(to_charlist(path)) do
        {:ok, conn} -> conn
        error -> raise("failed to open the database with error: #{inspect(error)}")
      end

    send(self(), :migrate)

    {:ok, state(conn: conn, statements: %{})}
  end

  @doc false
  def conn(pid \\ __MODULE__) do
    GenServer.call(pid, :conn)
  end

  @spec ensure_user_exists(pos_integer) :: :ok
  @spec ensure_user_exists(module | pid, pos_integer) :: :ok
  def ensure_user_exists(pid \\ __MODULE__, telegram_id) do
    insert_user(pid, telegram_id)
    :ok
  end

  @spec user(pos_integer) :: User.t() | nil
  @spec user(module | pid, pos_integer) :: User.t() | nil
  def user(pid \\ __MODULE__, telegram_id) do
    case GenServer.call(pid, {:user, telegram_id}) do
      [{^telegram_id, rolls_left, address, credit}] ->
        %User{
          telegram_id: _ensure_defined(telegram_id),
          rolls_left: _ensure_defined(rolls_left),
          seedit_address: _address(address),
          credit: _ensure_defined(credit)
        }

      [] ->
        nil
    end
  end

  @spec insert_user(pos_integer) :: :ok | (other :: any)
  @spec insert_user(module | pid, pos_integer) :: :ok | (other :: any)
  def insert_user(pid \\ __MODULE__, telegram_id) do
    GenServer.call(pid, {:insert_user, telegram_id})
  end

  @spec set_seedit_address(pos_integer, <<_::168>>) :: :ok | (other :: any)
  @spec set_seedit_address(module | pid, pos_integer, <<_::168>>) :: :ok | (other :: any)
  def set_seedit_address(pid \\ __MODULE__, telegram_id, <<address::21-bytes>>) do
    GenServer.call(pid, {:set_seedit_address, telegram_id, address})
  end

  @spec users :: [User.t()]
  @spec users(module | pid) :: [User.t()]
  def users(pid \\ __MODULE__) do
    pid
    |> GenServer.call(:users)
    |> Enum.map(fn {telegram_id, rolls_left, address, credit} ->
      %User{
        telegram_id: _ensure_defined(telegram_id),
        rolls_left: _ensure_defined(rolls_left),
        seedit_address: _address(address),
        credit: _ensure_defined(credit)
      }
    end)
  end

  @spec change_rolls_count(pos_integer, integer) :: :ok | (other :: any)
  @spec change_rolls_count(module | pid, pos_integer, integer) :: :ok | (other :: any)
  def change_rolls_count(pid \\ __MODULE__, telegram_id, count) do
    GenServer.call(pid, {:change_rolls_count, telegram_id, count})
  end

  @spec change_credit(pos_integer, integer) :: :ok | (other :: any)
  @spec change_credit(module | pid, pos_integer, integer) :: :ok | (other :: any)
  def change_credit(pid \\ __MODULE__, telegram_id, credit_change) do
    GenServer.call(pid, {:change_credit, telegram_id, credit_change})
  end

  @spec set_credit(pos_integer, non_neg_integer) :: :ok | (other :: any)
  @spec set_credit(module | pid, pos_integer, non_neg_integer) :: :ok | (other :: any)
  def set_credit(pid \\ __MODULE__, telegram_id, credit) do
    GenServer.call(pid, {:set_credit, telegram_id, credit})
  end

  @spec pool_size :: pos_integer
  @spec pool_size(module | pid) :: pos_integer
  def pool_size(pid \\ __MODULE__) do
    [{pool_size}] = GenServer.call(pid, :pool_size)
    pool_size
  end

  @spec reset_pool_size(pos_integer) :: :ok
  @spec reset_pool_size(module | pid, pos_integer) :: :ok
  def reset_pool_size(pid \\ __MODULE__, new_pool_size) do
    GenServer.call(pid, {:reset_pool_size, new_pool_size})
  end

  @spec change_pool_size(integer) :: :ok | {:error, :overdraft}
  @spec change_pool_size(module | pid, integer) :: :ok | {:error, :overdraft}
  def change_pool_size(pid \\ __MODULE__, change) do
    GenServer.call(pid, {:change_pool_size, change})
  end

  @spec roll_pic_file_id(String.t()) :: String.t() | nil
  @spec roll_pic_file_id(module | pid, String.t()) :: String.t() | nil
  def roll_pic_file_id(pid \\ __MODULE__, bot_id) do
    case GenServer.call(pid, {:roll_pic, bot_id}) do
      [{file_id}] -> file_id
      [] -> nil
    end
  end

  @spec set_roll_pic(String.t(), String.t()) :: :ok
  @spec set_roll_pic(module | pid, String.t(), String.t()) :: :ok
  def set_roll_pic(pid \\ __MODULE__, bot_id, file_id) do
    GenServer.call(pid, {:set_roll_pic, bot_id, file_id})
  end

  @spec initialized_rooms(String.t()) :: [room_id :: integer]
  @spec initialized_rooms(module | pid, String.t()) :: [room_id :: integer]
  def initialized_rooms(pid \\ __MODULE__, phone_number) do
    pid
    |> GenServer.call({:initialized_rooms, phone_number})
    |> Enum.map(fn {room_id} -> room_id end)
  end

  @spec insert_initialized_room(String.t(), integer) :: :ok | (other :: any)
  @spec insert_initialized_room(module | pid, String.t(), integer) :: :ok | (other :: any)
  def insert_initialized_room(pid \\ __MODULE__, phone_number, room_id) do
    GenServer.call(pid, {:insert_initialized_room, phone_number, room_id})
  end

  @spec delete_initialized_room(String.t(), integer) :: :ok | (other :: any)
  @spec delete_initialized_room(module | pid, String.t(), integer) :: :ok | (other :: any)
  def delete_initialized_room(pid \\ __MODULE__, phone_number, room_id) do
    GenServer.call(pid, {:delete_initialized_room, phone_number, room_id})
  end

  @spec reset_initialized_rooms(String.t()) :: :ok
  @spec reset_initialized_rooms(module | pid, String.t()) :: :ok
  def reset_initialized_rooms(pid \\ __MODULE__, phone_number) do
    GenServer.call(pid, {:reset_initialized_rooms, phone_number})
  end

  defp _address(:undefined), do: nil
  defp _address({:blob, address}), do: address

  defp _ensure_defined(:undefined), do: raise("unexpected undefined")
  defp _ensure_defined(other), do: other

  @doc false
  def handle_call(message, from, state)

  def handle_call({:change_pool_size, change}, _from, state) do
    sql = "UPDATE kv SET value = value + ? WHERE key = 'pool_size'"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [change])
    {:reply, run(statement), state}
  end

  def handle_call(:pool_size, _from, state) do
    sql = "SELECT value FROM kv WHERE key = 'pool_size'"
    {:ok, statement, state} = prepared_statement(sql, state)
    {:reply, :esqlite3.fetchall(statement), state}
  end

  def handle_call({:reset_pool_size, new_pool_size}, _from, state) do
    sql = "UPDATE kv SET value = ? WHERE key = 'pool_size'"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [new_pool_size])
    {:reply, run(statement), state}
  end

  def handle_call({:change_rolls_count, telegram_id, count}, _from, state) do
    sql = "UPDATE users SET rolls_left = rolls_left + ? WHERE telegram_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [count, telegram_id])
    {:reply, run(statement), state}
  end

  def handle_call({:change_credit, telegram_id, credit_change}, _from, state) do
    sql = "UPDATE users SET credit = credit + ? WHERE telegram_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [credit_change, telegram_id])
    {:reply, run(statement), state}
  end

  def handle_call({:set_credit, telegram_id, credit}, _from, state) do
    sql = "UPDATE users SET credit = ? WHERE telegram_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [credit, telegram_id])
    {:reply, run(statement), state}
  end

  def handle_call({:set_seedit_address, telegram_id, address}, _from, state) do
    sql = "UPDATE users SET seedit_address = ? WHERE telegram_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [{:blob, address}, telegram_id])
    {:reply, run(statement), state}
  end

  def handle_call({:insert_user, telegram_id}, _from, state) do
    sql = "INSERT INTO users (telegram_id) VALUES (?)"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [telegram_id])
    {:reply, run(statement), state}
  end

  def handle_call({:user, telegram_id}, _from, state) do
    sql =
      "SELECT telegram_id, rolls_left, seedit_address, credit FROM users WHERE telegram_id = ?"

    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [telegram_id])
    {:reply, :esqlite3.fetchall(statement), state}
  end

  def handle_call(:users, _from, state) do
    sql = "SELECT telegram_id, rolls_left, seedit_address, credit FROM users"
    {:ok, statement, state} = prepared_statement(sql, state)
    {:reply, :esqlite3.fetchall(statement), state}
  end

  def handle_call({:roll_pic, bot_id}, _from, state) do
    sql = "SELECT file_id FROM roll_pics WHERE bot_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [bot_id])
    {:reply, :esqlite3.fetchall(statement), state}
  end

  def handle_call({:set_roll_pic, bot_id, file_id}, _from, state) do
    sql = "INSERT OR REPLACE INTO roll_pics (bot_id, file_id) VALUES (?, ?)"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [bot_id, file_id])
    {:reply, run(statement), state}
  end

  def handle_call({:initialized_rooms, phone_number}, _from, state) do
    sql = "SELECT room_id FROM initialized_rooms WHERE phone_number = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [phone_number])
    {:reply, :esqlite3.fetchall(statement), state}
  end

  def handle_call({:insert_initialized_room, phone_number, room_id}, _from, state) do
    sql = "INSERT INTO initialized_rooms (phone_number, room_id) VALUES (?, ?)"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [phone_number, room_id])
    {:reply, run(statement), state}
  end

  def handle_call({:delete_initialized_room, phone_number, room_id}, _from, state) do
    sql = "DELETE FROM initialized_rooms WHERE phone_number = ? AND room_id = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [phone_number, room_id])
    {:reply, run(statement), state}
  end

  def handle_call({:reset_initialized_rooms, phone_number}, _from, state) do
    sql = "DELETE FROM initialized_rooms WHERE phone_number = ?"
    {:ok, statement, state} = prepared_statement(sql, state)
    :ok = :esqlite3.bind(statement, [phone_number])
    {:reply, run(statement), state}
  end

  def handle_call(:conn, _from, state(conn: conn) = state) do
    {:reply, conn, state}
  end

  @doc false
  def handle_info(:migrate, state(conn: conn) = state) do
    migrations = """
    -- TODO: CREATE TABLE migrations

    BEGIN;

    CREATE TABLE IF NOT EXISTS users (
      telegram_id INTEGER PRIMARY KEY,
      rolls_left INTEGER DEFAULT 0,
      seedit_address BLOB,
      credit INTEGER DEFAULT 0
      CHECK (rolls_left >= 0)
      CHECK (credit >= 0)
    );

    CREATE TABLE IF NOT EXISTS kv (
      key TEXT PRIMARY KEY,
      value INTEGER
    );

    CREATE TABLE IF NOT EXISTS roll_pics (
      bot_id TEXT PRIMARY KEY,
      file_id TEXT
    );

    CREATE TABLE IF NOT EXISTS initialized_rooms (
      phone_number TEXT,
      room_id INTEGER,
      PRIMARY KEY (phone_number, room_id)
    );

    INSERT OR IGNORE INTO kv (key, value) VALUES ('pool_size', 0);

    -- TODO: TABLE tips
    -- TODO: TABLE rolls
    -- TODO: TABLE events?

    COMMIT;
    """

    :ok = :esqlite3.exec(migrations, conn)
    {:noreply, state}
  end

  @spec prepared_statement(sql, state) :: {:ok, statement, state} | {:error, reason :: any, state}
  defp prepared_statement(sql, state(conn: conn, statements: statements) = state) do
    if statement = Map.get(statements, sql) do
      {:ok, statement, state}
    else
      case :esqlite3.prepare(sql, conn) do
        {:ok, statement} ->
          {:ok, statement, state(state, statements: Map.put(statements, sql, statement))}

        other ->
          other
      end
    end
  end

  @spec run(statement) :: :ok | tuple()
  defp run(statement) do
    case :esqlite3.step(statement) do
      :"$done" -> :ok
      :"$busy" -> {:error, :busy}
      other -> other
    end
  end
end
