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

  describe "tip" do
    test "100 TRX (valid)" do
      tipper_id = 12_341_234
      chat_id = -112_341_234_234
      tipper_username = "durov"
      txid = Base.encode16("trx100", case: :lower)

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
      tipper_id = 12_34_234
      chat_id = -112_34_234_234
      tipper_username = "durov"

      txid = Base.encode16("trx70", case: :lower)
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

      txid = Base.encode16("trx35", case: :lower)
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
  end
end
