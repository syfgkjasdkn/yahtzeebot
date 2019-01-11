defmodule CoreTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Storage.start_link(path: "", name: Storage)
    :ok = Application.put_env(:core, :shared_tron_test_process, self())
    :ok = Application.put_env(:ubot, :tracked_chat_ids, [])
    :ok
  end

  describe "trx tip" do
    setup do
      assert "TRX" == Core.token_id()
      assert "TRX" == Core.token_name()
      :ok
    end

    test "increases roll count" do
      tipper_id = 1234
      txid = Base.encode16("TRX:100", case: :lower)

      assert 0 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 3, _pool_size} = Core.process_tip(tipper_id, txid)
      assert 3 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 6, _pool_size} = Core.process_tip(tipper_id, txid)
      assert 6 == Core.Session.rolls_left(tipper_id)
    end

    test "persists seedit address" do
      tipper_id = 12_331_234
      tipper_address = :crypto.strong_rand_bytes(21)

      refute Core.Session.seedit_address(tipper_id)

      assert {:ok, _roll_count, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferContract{amount: 100_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert tipper_address == Core.Session.seedit_address(tipper_id)
    end

    test "only accepts TRX" do
      tipper_id = 12331
      tipper_address = :crypto.strong_rand_bytes(21)

      assert {:ok, _roll_count, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferContract{amount: 100_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert {:error, :invalid_token} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 100_000_000,
                   asset_name: "SomeToken",
                   owner_address: tipper_address
                 },
                 tipper_id
               )
    end

    test "converts 100 trx to 3 rolls" do
      tipper_id = 12332
      tipper_address = :crypto.strong_rand_bytes(21)

      assert 0 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 3, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferContract{amount: 100_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert 3 == Core.Session.rolls_left(tipper_id)
    end

    test "increases pool size" do
      tipper_id = 1_223_435
      txid = Base.encode16("TRX:100", case: :lower)

      assert 0 == Core.pool_size()

      assert {:ok, _roll_count, 100} = Core.process_tip(tipper_id, txid)
      assert 100 == Core.pool_size()

      assert {:ok, _roll_count, 200} = Core.process_tip(tipper_id, txid)
      assert 200 == Core.pool_size()
    end

    test "carries TRX credit over on invalid TRX tip" do
      tipper_id = 21567
      tipper_address = :crypto.strong_rand_bytes(21)

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 0 == Core.Session.credit(tipper_id)

      assert {:ok, :credited, 1} ==
               Core.process_transfer(
                 %Tron.TransferContract{amount: 1_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 1 == Core.Session.credit(tipper_id)

      assert {:ok, :credited, 81} ==
               Core.process_transfer(
                 %Tron.TransferContract{amount: 80_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 81 == Core.Session.credit(tipper_id)

      assert {:ok, 3, 101} ==
               Core.process_transfer(
                 %Tron.TransferContract{amount: 20_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 1 == Core.Session.credit(tipper_id)
    end
  end

  describe "token tip" do
    setup [:setup_token]

    test "increases roll count" do
      tipper_id = 1_223_441_322_734
      txid = Base.encode16("1234567:100", case: :lower)

      assert 0 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 3, _pool_size} = Core.process_tip(tipper_id, txid)
      assert 3 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 6, _pool_size} = Core.process_tip(tipper_id, txid)
      assert 6 == Core.Session.rolls_left(tipper_id)
    end

    test "persists seedit address" do
      tipper_id = 123_345_234
      tipper_address = :crypto.strong_rand_bytes(21)

      refute Core.Session.seedit_address(tipper_id)

      assert {:ok, _roll_count, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 100,
                   asset_name: "1234567",
                   owner_address: tipper_address
                 },
                 tipper_id
               )

      assert tipper_address == Core.Session.seedit_address(tipper_id)
    end

    test "only accepts SomeToken" do
      tipper_id = 122_311
      tipper_address = :crypto.strong_rand_bytes(21)

      assert {:ok, _roll_count, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 100,
                   asset_name: "1234567",
                   owner_address: tipper_address
                 },
                 tipper_id
               )

      assert {:error, :invalid_token} =
               Core.process_transfer(
                 %Tron.TransferContract{amount: 100_000_000, owner_address: tipper_address},
                 tipper_id
               )

      assert {:error, :invalid_token} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 100,
                   asset_name: "1234568",
                   owner_address: tipper_address
                 },
                 tipper_id
               )
    end

    test "converts 100 SomeToken to 3 rolls" do
      tipper_id = 2_435_332
      tipper_address = :crypto.strong_rand_bytes(21)

      assert 0 == Core.Session.rolls_left(tipper_id)

      assert {:ok, 3, _pool_size} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 100,
                   owner_address: tipper_address,
                   asset_name: "1234567"
                 },
                 tipper_id
               )

      assert 3 == Core.Session.rolls_left(tipper_id)
    end

    test "increases pool size" do
      tipper_id = 12_232_335
      txid = Base.encode16("1234567:100", case: :lower)

      assert 0 == Core.pool_size()

      assert {:ok, _roll_count, 100} = Core.process_tip(tipper_id, txid)
      assert 100 == Core.pool_size()

      assert {:ok, _roll_count, 200} = Core.process_tip(tipper_id, txid)
      assert 200 == Core.pool_size()
    end

    test "carries SomeToken credit over on invalid SomeToken tip" do
      tipper_id = 215_634
      tipper_address = :crypto.strong_rand_bytes(21)

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 0 == Core.Session.credit(tipper_id)

      assert {:ok, :credited, 1} ==
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 1,
                   asset_name: "1234567",
                   owner_address: tipper_address
                 },
                 tipper_id
               )

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 1 == Core.Session.credit(tipper_id)

      assert {:ok, :credited, 81} ==
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 80,
                   asset_name: "1234567",
                   owner_address: tipper_address
                 },
                 tipper_id
               )

      assert 0 == Core.Session.rolls_left(tipper_id)
      assert 81 == Core.Session.credit(tipper_id)

      assert {:ok, 3, 101} ==
               Core.process_transfer(
                 %Tron.TransferAssetContract{
                   amount: 20,
                   asset_name: "1234567",
                   owner_address: tipper_address
                 },
                 tipper_id
               )

      assert 3 == Core.Session.rolls_left(tipper_id)
      assert 1 == Core.Session.credit(tipper_id)
    end
  end

  describe "admins" do
    test "admin?/1" do
      # these come form the initial config
      assert Core.admin?(666)
      assert Core.admin?(777)

      refute Core.admin?(123)

      # add 123 as an admin
      :ok = Application.put_env(:core, :admin_ids, [666, 777, 123])

      assert Core.admin?(666)
      assert Core.admin?(777)
      assert Core.admin?(123)
    end
  end

  describe "initialized rooms" do
    test "initialize_room/1 and deinitialize_room/1" do
      assert phone_number = Application.get_env(:ubot, :phone_number)

      room_id1 = -123_456
      room_id2 = -1_234_567

      assert :ok == Core.initialize_room(room_id1)
      assert [room_id1] == Application.get_env(:ubot, :tracked_chat_ids)
      assert [room_id1] == Storage.initialized_rooms(phone_number)

      assert {:error,
              {:constraint,
               'UNIQUE constraint failed: initialized_rooms.phone_number, initialized_rooms.room_id'}} ==
               Core.initialize_room(room_id1)

      assert [room_id1] == Application.get_env(:ubot, :tracked_chat_ids)
      assert [room_id1] == Storage.initialized_rooms(phone_number)

      assert :ok == Core.initialize_room(room_id2)

      assert Enum.sort([room_id1, room_id2]) ==
               Enum.sort(Application.get_env(:ubot, :tracked_chat_ids))

      assert Enum.sort([room_id1, room_id2]) == Enum.sort(Storage.initialized_rooms(phone_number))

      assert :ok == Core.deinitialize_room(room_id1)
      assert [room_id2] == Application.get_env(:ubot, :tracked_chat_ids)
      assert [room_id2] == Storage.initialized_rooms(phone_number)
    end
  end

  describe "roll" do
    test "decreases roll count" do
      tipper_id = 12335
      winner_address = :crypto.strong_rand_bytes(21)

      assert 10 = Core.Session.add_rolls(tipper_id, 10)
      assert 10 = Core.Session.rolls_left(tipper_id)
      assert :ok = Core.Session.set_seedit_address(tipper_id, winner_address)

      # FIXME
      _ = :rand.seed(:exs1024s, {111, 123_534, 345_345})

      case Core.roll(tipper_id) do
        {:ok, {:lose, _}} ->
          assert 9 == Core.Session.rolls_left(tipper_id)

        {:ok, {:win, :extra_roll, _}} ->
          assert 10 == Core.Session.rolls_left(tipper_id)

        {:ok, {:win, _, _}, _} ->
          assert 9 == Core.Session.rolls_left(tipper_id)

        {:ok, {:win, _, _}} ->
          assert 9 == Core.Session.rolls_left(tipper_id)
      end
    end

    test "sends reward on win" do
      tipper_id = 12336
      winner_address = :crypto.strong_rand_bytes(21)

      assert :ok = Core.Session.set_seedit_address(tipper_id, winner_address)
      assert 100_000 = Core.Session.add_rolls(tipper_id, 100_000)
      assert :ok = Storage.change_pool_size(+10000)

      # TODO use seeds to predetermine the roll outcome
      Enum.reduce(1..10000, Storage.pool_size(), fn _, prev_pool_size ->
        case Core.roll(tipper_id) do
          {:ok, {:win, :large_straight, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "TRX", address: ^winner_address, amount: 200}
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size - 200
            pool_size

          {:ok, {:win, :four_of_kind, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "TRX", address: ^winner_address, amount: 400}
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size - 400
            pool_size

          {:ok, {:win, :pool, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "TRX", address: ^winner_address, amount: amount}
            assert_in_delta amount, 0.8 * prev_pool_size, 10
            Storage.change_pool_size(+10000)
            Storage.pool_size()

          _other ->
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size
            pool_size
        end
      end)
    end

    test "sends token reward on win" do
      setup_token()

      tipper_id = 1_223_461_111_336
      winner_address = :crypto.strong_rand_bytes(21)

      assert :ok = Core.Session.set_seedit_address(tipper_id, winner_address)
      assert 100_000 = Core.Session.add_rolls(tipper_id, 100_000)
      assert :ok = Storage.change_pool_size(+10000)

      # TODO use seeds to predetermine the roll outcome
      Enum.reduce(1..10000, Storage.pool_size(), fn _, prev_pool_size ->
        case Core.roll(tipper_id) do
          {:ok, {:win, :large_straight, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "1234567", address: ^winner_address, amount: 200}
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size - 200
            pool_size

          {:ok, {:win, :four_of_kind, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "1234567", address: ^winner_address, amount: 400}
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size - 400
            pool_size

          {:ok, {:win, :pool, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, token: "1234567", address: ^winner_address, amount: amount}
            assert_in_delta amount, 0.8 * prev_pool_size, 10
            Storage.change_pool_size(+10000)
            Storage.pool_size()

          _other ->
            pool_size = Storage.pool_size()
            assert pool_size == prev_pool_size
            pool_size
        end
      end)
    end
  end

  describe "pool_size_cap" do
    test "with TRX" do
      assert 1_000_000 == Core.pool_size_cap()

      :ok = Application.put_env(:core, :pool_size_cap, 1000)

      assert 1000 == Core.pool_size_cap()
      assert 0 == Core.pool_size()

      tipper_id = 1_223_432_435

      txid = Base.encode16("TRX:100", case: :lower)
      assert {:ok, _roll_count, 100} = Core.process_tip(tipper_id, txid)
      assert 100 == Core.pool_size()

      txid = Base.encode16("TRX:850", case: :lower)
      assert {:ok, _roll_count, 950} = Core.process_tip(tipper_id, txid)
      assert 950 == Core.pool_size()

      txid = Base.encode16("TRX:70", case: :lower)
      assert {:ok, _roll_count, 1000} = Core.process_tip(tipper_id, txid)
      assert 1000 == Core.pool_size()

      txid = Base.encode16("TRX:700", case: :lower)
      assert {:ok, _roll_count, 1000} = Core.process_tip(tipper_id, txid)
      assert 1000 == Core.pool_size()

      :ok = Application.put_env(:core, :pool_size_cap, 1_000_000)
    end

    test "with SomeToken" do
      setup_token()

      assert 1_000_000 == Core.pool_size_cap()

      :ok = Application.put_env(:core, :pool_size_cap, 1000)

      assert 1000 == Core.pool_size_cap()
      assert 0 == Core.pool_size()

      tipper_id = 1_223_432_435_654

      txid = Base.encode16("1234567:100", case: :lower)
      assert {:ok, _roll_count, 100} = Core.process_tip(tipper_id, txid)
      assert 100 == Core.pool_size()

      txid = Base.encode16("1234567:850", case: :lower)
      assert {:ok, _roll_count, 950} = Core.process_tip(tipper_id, txid)
      assert 950 == Core.pool_size()

      txid = Base.encode16("1234567:70", case: :lower)
      assert {:ok, _roll_count, 1000} = Core.process_tip(tipper_id, txid)
      assert 1000 == Core.pool_size()

      txid = Base.encode16("1234567:700", case: :lower)
      assert {:ok, _roll_count, 1000} = Core.process_tip(tipper_id, txid)
      assert 1000 == Core.pool_size()

      :ok = Application.put_env(:core, :pool_size_cap, 1_000_000)
    end
  end

  defp setup_token(_context) do
    setup_token()
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
