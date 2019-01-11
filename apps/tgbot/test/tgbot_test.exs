defmodule TGBotTest do
  use ExUnit.Case

  setup tags do
    if tags[:async] do
      raise("cannot use async tests since Core.Tron.TestAdapter uses a shared process")
    end

    {:ok, _} = Storage.start_link(path: "", name: Storage)
    :ok = Application.put_env(:core, :shared_tron_test_process, self())
    :ok = Application.put_env(:ubot, :tracked_chat_ids, [])

    :ok
  end

  test "ignores private messages" do
    telegram_id = 100
    send_private_message(telegram_id, "/start")
    refute_receive _anything
  end

  test "unmatched command or text message are ignored" do
    telegram_id = 102
    send_public_message(telegram_id, "asdfasdf")
    send_public_message(telegram_id, "/asdfasdf")
    refute_receive _anything
  end

  describe "/init and /deinit" do
    test "by admin" do
      # this is one of the admins in the test config
      telegram_id = 666

      send_public_message(telegram_id, "/init", chat_id: -123_475)

      assert_receive {:message,
                      telegram_id: -123_475,
                      text: """
                      Initialized the bot for chat id -123475.
                      """,
                      opts: []}

      assert [-123_475] == Application.get_env(:ubot, :tracked_chat_ids)

      send_public_message(telegram_id, "/init", chat_id: -123_475)

      assert_receive {:message,
                      telegram_id: -123_475,
                      text: """
                      The bot has already been initialized for chat id -123475.
                      """,
                      opts: []}

      assert [-123_475] == Application.get_env(:ubot, :tracked_chat_ids)

      send_public_message(telegram_id, "/init", chat_id: -1_234_756)

      assert_receive {:message,
                      telegram_id: -1_234_756,
                      text: """
                      Initialized the bot for chat id -1234756.
                      """,
                      opts: []}

      assert [-1_234_756, -123_475] == Application.get_env(:ubot, :tracked_chat_ids)

      send_public_message(telegram_id, "/deinit", chat_id: -1_234_756)

      assert_receive {:message,
                      telegram_id: -1_234_756,
                      text: """
                      Deinitialized the bot for chat id -1234756.
                      """,
                      opts: []}

      assert [-123_475] == Application.get_env(:ubot, :tracked_chat_ids)
    end

    test "by stranger" do
      telegram_id = 1_236_578

      send_public_message(telegram_id, "/init", chat_id: -123_876_032)

      refute_receive _anything

      assert [] == Application.get_env(:ubot, :tracked_chat_ids)
    end
  end

  describe "set roll animation" do
    test "when admin" do
      # this is one of the admins in the test config
      telegram_id = 666
      send_animation(telegram_id, "CgADAgAD6gIAAvGQOUizEEpQ6k88OgI")
      assert "CgADAgAD6gIAAvGQOUizEEpQ6k88OgI" == Core.roll_outcome_file_id()
    end

    test "when not admin" do
      telegram_id = 619_283_746_129_837
      send_animation(telegram_id, "CgADAgAD6gIAAvGQOUizEEpQ6k88OgI")
      refute Core.roll_outcome_file_id()
    end
  end

  describe "/pool" do
    test "with TRX" do
      telegram_id = 101_234
      assert :ok = Storage.change_pool_size(+10000)

      send_public_message(telegram_id, "/pool")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      Current pool size is 10000 TRX
                      """,
                      opts: []}
    end

    test "with tokens" do
      setup_token()

      telegram_id = 101_234_199
      assert :ok = Storage.change_pool_size(+10000)

      send_public_message(telegram_id, "/pool")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      Current pool size is 10000 SomeToken (1234567)
                      """,
                      opts: []}
    end
  end

  test "/rolls_left" do
    telegram_id = 1_232_345

    send_public_message(telegram_id, "/rolls_left")

    assert_receive {:message,
                    telegram_id: ^telegram_id,
                    text: """
                    @durov you have 0 roll(s) left
                    """,
                    opts: []}

    assert 3 = Core.Session.add_rolls(telegram_id, 3)

    send_public_message(telegram_id, "/rolls_left")

    assert_receive {:message,
                    telegram_id: ^telegram_id,
                    text: """
                    @durov you have 3 roll(s) left
                    """,
                    opts: []}
  end

  describe "/credit" do
    test "with trx" do
      telegram_id = 1_232_34523

      send_public_message(telegram_id, "/credit")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      @durov your credit is 0 TRX
                      """,
                      opts: []}

      # TODO
      assert :ok == Storage.change_credit(telegram_id, +70)

      send_public_message(telegram_id, "/credit")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      @durov your credit is 70 TRX
                      """,
                      opts: []}
    end

    test "with tokens" do
      setup_token()

      telegram_id = 1_232_345_242_111_223

      send_public_message(telegram_id, "/credit")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      @durov your credit is 0 SomeToken (1234567)
                      """,
                      opts: []}

      # TODO
      assert :ok == Storage.change_credit(telegram_id, +70)

      send_public_message(telegram_id, "/credit")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      @durov your credit is 70 SomeToken (1234567)
                      """,
                      opts: []}
    end
  end

  describe "/roll" do
    test "when have rolls" do
      telegram_id = 10543

      assert :ok = Core.Session.set_seedit_address(telegram_id, :crypto.strong_rand_bytes(21))
      assert 3 = Core.Session.add_rolls(telegram_id, 3)

      send_public_message(telegram_id, "/roll")

      assert_receive {:message, telegram_id: ^telegram_id, text: text, opts: _opts}
      assert String.contains?(text, ["@durov rolled"])
    end

    test "when have rolls and roll pic" do
      telegram_id = 123_756_821

      assert :ok = Core.set_roll_outcome_file_id("CgADAgAD6gIAAvGQOUizEEpQ6k88OgI")
      assert :ok = Core.Session.set_seedit_address(telegram_id, :crypto.strong_rand_bytes(21))
      assert 3 = Core.Session.add_rolls(telegram_id, 3)

      send_public_message(telegram_id, "/roll")

      assert_receive {:document,
                      telegram_id: ^telegram_id,
                      file_id: "CgADAgAD6gIAAvGQOUizEEpQ6k88OgI",
                      opts: opts}

      assert String.contains?(opts[:caption], ["@durov rolled"])
    end

    test "when don't have rolls" do
      telegram_id = 101

      send_public_message(telegram_id, "/roll")

      assert_receive {:message,
                      telegram_id: 101,
                      text: """
                      @durov you don't have any rolls left.

                      Please /tip 100 the bot to get 3 rolls.
                      """,
                      opts: []}
    end

    test "when don't have rolls (with tokens)" do
      setup_token()

      telegram_id = 10_112_763_845_976_352

      send_public_message(telegram_id, "/roll")

      assert_receive {:message,
                      telegram_id: ^telegram_id,
                      text: """
                      @durov you don't have any rolls left.

                      Please /tip 100 SomeToken the bot to get 3 rolls.
                      """,
                      opts: []}
    end
  end

  describe "/message" do
    test "from admin" do
      telegram_id = 666

      send_public_message(telegram_id, "/message this should be repeated")

      assert_receive {:message,
                      telegram_id: ^telegram_id, text: "this should be repeated", opts: []}

      send_public_message(telegram_id, "/message@some_bot this also should be repeated")

      assert_receive {:message,
                      telegram_id: ^telegram_id, text: "this also should be repeated", opts: []}
    end

    test "not from admin" do
      telegram_id = 664

      send_public_message(telegram_id, "/message this shouldn't be repeated")

      refute_receive {:message, _anything}

      send_public_message(telegram_id, "/message@some_bot this shouldn't be repeated either")

      refute_receive {:message, _anything}
    end
  end

  test "set_webhook" do
    TGBot.set_webhook(url: "https://some.website/tgbot", certificate: "priv/somekey.pem")

    assert_receive {:webhook,
                    url: "https://some.website/tgbot/1263745172:iugyaksdfhjfgrgyuwekfhjsdb",
                    certificate: "priv/somekey.pem"}
  end

  defp send_private_message(telegram_id, text) do
    TGBot.handle(%{
      "message" => %{
        "from" => %{"id" => telegram_id},
        "chat" => %{"id" => telegram_id, "type" => "private"},
        "text" => text
      }
    })
  end

  defp send_public_message(telegram_id, text, opts \\ []) do
    TGBot.handle(%{
      "message" => %{
        "from" => %{"id" => telegram_id, "username" => "durov"},
        "chat" => %{"id" => opts[:chat_id] || telegram_id, "type" => "supergroup"},
        "text" => text
      }
    })
  end

  defp send_animation(telegram_id, file_id) do
    TGBot.handle(%{
      "message" => %{
        "animation" => %{"file_id" => file_id, "mime_type" => "video/mp4"},
        "caption" => "/roll_pic",
        "from" => %{"id" => telegram_id}
      }
    })
  end

  defp setup_token do
    prev_token_id = Core.token_id()
    prev_token_name = Core.token_name()

    :ok = Application.put_env(:core, :token_id, "1234567")
    :ok = Application.put_env(:core, :token_name, "SomeToken")

    assert "SomeToken (1234567)" == Core.full_token_name()

    on_exit(fn ->
      Application.put_env(:core, :token_id, prev_token_id)
      Application.put_env(:core, :token_name, prev_token_name)
    end)
  end
end
