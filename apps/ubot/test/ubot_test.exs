defmodule UbotTest do
  use ExUnit.Case

  setup tags do
    if tags[:async] do
      raise("cannot use async tests since Core.Tron.TestAdapter uses a shared process")
    end

    {:ok, _} = Storage.start_link(path: "", name: Storage)
    :ok = Application.put_env(:core, :shared_tron_test_process, self())

    :ok
  end

  describe "trx tip" do
    test "100 TRX (valid)" do
      tipper_id = 12_341_234
      chat_id = -112_341_234_234
      tipper_username = "durov"
      txid = Base.encode16("TRX:100", case: :lower)

      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 3 roll(s)

                      Pool size: 100 TRX
                      """,
                      opts: []}

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 100 == Core.pool_size()

      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 6 roll(s)

                      Pool size: 200 TRX
                      """,
                      opts: []}

      assert 6 == Core.Session.rolls_left(tipper_id)
      assert 200 == Core.pool_size()
    end

    test "several <100 TRX via credits" do
      tipper_id = 1_234_234
      chat_id = -112_34_234_234
      tipper_username = "durov"

      txid = Base.encode16("TRX:70", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov you tipped an invalid amount.

                      Pool size: 70 TRX
                      """,
                      opts: []}

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 70 == Core.Session.credit(tipper_id)
      assert 70 == Core.pool_size()

      txid = Base.encode16("TRX:35", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 3 roll(s)

                      Pool size: 105 TRX
                      """,
                      opts: []}

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 5 == Core.Session.credit(tipper_id)
      assert 105 == Core.pool_size()
    end

    test "non trx tip" do
      tipper_id = 123_423_432_345
      chat_id = -112_34_234_234
      tipper_username = "durov"

      txid = Base.encode16("SomeToken:70", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      🚨 The bot only accepts 100 TRX tips.

                      Try /tip 100 to get 3 rolls
                      """,
                      opts: []}

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 0 == Core.Session.credit(tipper_id)
      assert 0 == Core.pool_size()
    end
  end

  describe "token tip" do
    setup do
      prev_token = Core.token()

      :ok = Application.put_env(:core, :token, "SomeToken")

      assert "SomeToken" == Core.token()

      on_exit(fn ->
        Application.put_env(:core, :token, prev_token)
      end)
    end

    test "100 SomeToken (valid)" do
      tipper_id = 1_234_123_423
      chat_id = -112_341_234_234_532
      tipper_username = "durov"
      txid = Base.encode16("SomeToken:100", case: :lower)

      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 3 roll(s)

                      Pool size: 100 SomeToken
                      """,
                      opts: []}

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 100 == Core.pool_size()

      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 6 roll(s)

                      Pool size: 200 SomeToken
                      """,
                      opts: []}

      assert 6 == Core.Session.rolls_left(tipper_id)
      assert 200 == Core.pool_size()
    end

    test "several <100 SomeToken via credits" do
      tipper_id = 12_211_234_234_124
      chat_id = -11_234_234_234_534
      tipper_username = "durov"

      txid = Base.encode16("SomeToken:70", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov you tipped an invalid amount.

                      Pool size: 70 SomeToken
                      """,
                      opts: []}

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 70 == Core.Session.credit(tipper_id)
      assert 70 == Core.pool_size()

      txid = Base.encode16("SomeToken:35", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      @durov now has 3 roll(s)

                      Pool size: 105 SomeToken
                      """,
                      opts: []}

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 5 == Core.Session.credit(tipper_id)
      assert 105 == Core.pool_size()
    end

    test "invalid token tip" do
      tipper_id = 1_234_234_323_451_325_428
      chat_id = -112_34_234_234
      tipper_username = "durov"

      txid = Base.encode16("TRX:70", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      🚨 The bot only accepts 100 SomeToken tips.

                      Try /tip 100 SomeToken to get 3 rolls
                      """,
                      opts: []}

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 0 == Core.Session.credit(tipper_id)
      assert 0 == Core.pool_size()

      txid = Base.encode16("SomeOtherToken:70", case: :lower)
      UBot._process_tip(tipper_id, tipper_username, chat_id, txid)

      assert_receive {:message,
                      telegram_id: ^chat_id,
                      text: """
                      🚨 The bot only accepts 100 SomeToken tips.

                      Try /tip 100 SomeToken to get 3 rolls
                      """,
                      opts: []}

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 0 == Core.Session.credit(tipper_id)
      assert 0 == Core.pool_size()
    end
  end
end
