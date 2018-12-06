defmodule Web.Plugs.TGBot do
  @moduledoc false
  import Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  test_block =
    if Mix.env() == :test do
      quote do
        send(self(), :invalid_token)
      end
    end

  @impl true
  def call(%Plug.Conn{path_info: [token], params: params} = conn, _opts) do
    if TGBot.token() == token do
      valid_path(conn, params)
    else
      invalid_path(conn)
    end
  end

  def call(conn, _opts) do
    invalid_path(conn)
  end

  defp valid_path(conn, params) do
    TGBot.handle(params)
    send_resp(conn, 200, [])
  end

  defp invalid_path(conn) do
    unquote(test_block)
    send_resp(conn, 200, [])
  end
end
