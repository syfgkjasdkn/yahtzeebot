defmodule Web.Router do
  @moduledoc false
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  forward("/tgbot", to: Web.Plugs.TGBot)

  match _ do
    send_resp(conn, 404, [])
  end
end
