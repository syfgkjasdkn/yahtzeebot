defmodule Core.Application do
  @moduledoc false
  use Application

  children =
    Enum.reject(
      [
        if Mix.env() in [:prod, :dev] do
          {Storage,
           path: quote(do: Application.get_env(:core, :db_path) || raise("need core.db_path")),
           name: Storage}
        end,
        if Mix.env() in [:prod, :dev] do
          {Core.Tron, privkey: quote(do: Application.get_env(:core, :privkey))}
        end,
        {Registry, keys: :unique, name: Core.Session.Registry},
        Core.Session.Supervisor
      ],
      &is_nil/1
    )

  def start(_type, _args) do
    unless unquote(Mix.env() == :test) do
      ensure_loaded_env!()
    end

    children = unquote(children)
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
