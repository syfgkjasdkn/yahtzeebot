defmodule Core.SessionTest do
  use ExUnit.Case
  alias Core.Session
  alias Storage.User

  setup do
    {:ok, _} = Storage.start_link(path: "", name: Storage)

    :ok
  end

  test "load" do
    telegram_id = 400

    assert :ok = Storage.insert_user(telegram_id)
    assert %User{telegram_id: ^telegram_id, rolls_left: 0} = Storage.user(telegram_id)
    assert :ok = Storage.change_rolls_count(telegram_id, +10)

    assert Session.rolls_left(telegram_id) == 10
  end

  test "a new process is started on call" do
    telegram_id = 911
    assert 0 = Session.rolls_left(telegram_id)

    assert [{pid, _}] = Registry.lookup(Session.Registry, telegram_id)
    assert Process.alive?(pid)
  end

  test "seedit address" do
    telegram_id = 91234

    <<address::21-bytes, _checksum::4-bytes>> =
      Core.Base58.decode("TCyvSe3Wac9EErsURUcvFSVn5sWNcKaTKk")

    refute Session.seedit_address(telegram_id)
    assert :ok = Session.set_seedit_address(telegram_id, address)
    assert address == Session.seedit_address(telegram_id)
  end

  test "credit" do
    telegram_id = 123_717

    assert 0 == Session.credit(telegram_id)
    assert :ok == Session.set_credit(telegram_id, 30)
    assert 30 == Session.credit(telegram_id)
  end

  test "stop" do
    telegram_id = 912
    assert 0 = Session.rolls_left(telegram_id)

    assert [{pid, _}] = Registry.lookup(Session.Registry, telegram_id)
    assert Process.alive?(pid)

    assert Session.Supervisor.stop_session(telegram_id) == :ok

    # FIXME
    :timer.sleep(100)

    assert [] = Registry.lookup(Session.Registry, telegram_id)
    refute Process.alive?(pid)
  end

  test "roll" do
    telegram_id = 10012

    {:error, :no_rolls} = Session.roll(telegram_id)

    assert 1000 = Session.add_rolls(telegram_id, 1000)

    Enum.each(1..1000, fn _ ->
      assert {:ok, outcome} = Session.roll(telegram_id)

      case outcome do
        {:win, reward, dice} when is_list(dice) ->
          assert reward in [:extra_roll, :large_straight, :four_of_kind, :pool]
          assert length(dice) == 5

        {:lose, dice} when is_list(dice) ->
          assert length(dice) == 5
      end
    end)

    assert {:error, :no_rolls} = Session.roll(telegram_id)
    assert 0 = Session.rolls_left(telegram_id)
  end

  test "add rolls" do
    telegram_id = 1_001_234

    assert 0 = Session.rolls_left(telegram_id)

    assert 10 = Session.add_rolls(telegram_id, 10)
    assert 10 = Session.rolls_left(telegram_id)

    assert 16 = Session.add_rolls(telegram_id, 6)
    assert 16 = Session.rolls_left(telegram_id)

    assert 21 = Session.add_rolls(telegram_id, 5)
    assert 21 = Session.rolls_left(telegram_id)
  end
end
