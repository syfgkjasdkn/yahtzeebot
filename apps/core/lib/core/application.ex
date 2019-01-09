defmodule Core.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    config = Application.get_all_env(:core)

    if config[:ensure_loaded_env?] do
      ensure_loaded_env!()
    end

    maybe_children = [
      if db_path = config[:db_path] do
        {Storage, path: db_path, name: Storage}
      end,
      if config[:start_tron_pool?] do
        :poolboy.child_spec(Core.Tron.Pool,
          name: {:local, Core.Tron.Pool},
          worker_module: Core.Tron.Channel,
          size: 5,
          max_overflow: 2
        )
      end,
      {Registry, keys: :unique, name: Core.Session.Registry},
      Core.Session.Supervisor
    ]

    children = Enum.reject(maybe_children, &is_nil/1)

    opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ensure_loaded_env! do
    address_base58check =
      Application.get_env(:core, :address) || raise(ArgumentError, "need core.address")

    <<address::21-bytes, _checksum::4-bytes>> = Core.Base58.decode(address_base58check)
    Application.put_env(:core, :address, address)

    privkey_base16 =
      Application.get_env(:core, :privkey) || raise(ArgumentError, "need core.privkey")

    privkey = Base.decode16!(privkey_base16, case: :mixed)
    Application.put_env(:core, :privkey, privkey)

    owners_address_base58check =
      Application.get_env(:core, :owners_address) ||
        raise(ArgumentError, "need core.owners_address")

    <<owners_address::21-bytes, _checksum::4-bytes>> =
      Core.Base58.decode(owners_address_base58check)

    Application.put_env(:core, :owners_address, owners_address)
    Application.get_env(:core, :grpc_nodes) || raise(ArgumentError, "need core.grpc_nodes")
  end
end
