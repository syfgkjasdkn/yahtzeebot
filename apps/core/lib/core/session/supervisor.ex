defmodule Core.Session.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  @doc false
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_session(pos_integer) :: DynamicSupervisor.on_start_child()
  def start_session(telegram_id) when is_integer(telegram_id) do
    DynamicSupervisor.start_child(__MODULE__, {Core.Session, telegram_id: telegram_id})
  end

  @spec stop_session(pos_integer) :: :ok | {:error, :not_found}
  def stop_session(telegram_id) when is_integer(telegram_id) do
    case Registry.lookup(Core.Session.Registry, telegram_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end
end
