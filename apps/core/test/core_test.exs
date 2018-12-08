defmodule CoreTest do
  use ExUnit.Case

  setup do
    {:ok, _} = Storage.start_link(path: "", name: Storage)
    :ok = Application.put_env(:core, :shared_tron_test_process, self())
    :ok
  end

  describe "tip" do
    test "increases roll count" do
      tipper_id = 1234
      txid = Base.encode16("trx100", case: :lower)

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

      assert {:error, :invalid_contract} =
               Core.process_transfer(
                 %Tron.TransferAssetContract{amount: 100_000_000, asset_name: "SomeToken"},
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
      tipper_id = 1235
      txid = Base.encode16("trx100", case: :lower)

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
      Enum.each(1..10000, fn _ ->
        case Core.roll(tipper_id) do
          {:ok, {:win, :large_straight, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, address: ^winner_address, amount: 200}

          {:ok, {:win, :four_of_kind, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, address: ^winner_address, amount: 400}

          {:ok, {:win, :pool, _dice}, "tx87q32oiualfjbasdlkjfbasm"} ->
            assert_receive {:reward, address: ^winner_address, amount: amount}
            assert_in_delta amount, 0.8 * Core.pool_size(), 1000
            Storage.change_pool_size(+10000)

          _other ->
            nil
        end
      end)
    end
  end
end
