defmodule Web.Plugs.TGBotTest do
  use ExUnit.Case
  use Plug.Test

  @opts Web.Router.init([])

  setup do
    {:ok, _pid} = Storage.start_link(path: ":memory:", name: Storage)
    :ok
  end

  test "invalid token" do
    conn = Web.Router.call(conn(:post, "/tgbot/aksdjhfg"), @opts)
    assert conn.status == 200
    assert_receive(:invalid_token)
    refute_receive {:message, _telegram_id, _text}
  end

  test "no token" do
    conn = Web.Router.call(conn(:post, "/tgbot"), @opts)
    assert conn.status == 200
    assert_receive(:invalid_token)
    refute_receive {:message, _telegram_id, _text}
  end

  test "valid token" do
    conn =
      Web.Router.call(
        conn(:post, "/tgbot/#{TGBot.token()}", %{
          "message" => %{
            "text" => "/roll",
            "from" => %{"id" => 1_231_234, "username" => "john"},
            "chat" => %{"id" => -1_213_453, "type" => "group"}
          }
        }),
        @opts
      )

    assert conn.status == 200

    {:message,
     telegram_id: -1_213_453,
     text: """
     @john you don't have any rolls left.

     Please /tip 100 the bot to get 3 rolls.
     """,
     opts: []}
  end
end
