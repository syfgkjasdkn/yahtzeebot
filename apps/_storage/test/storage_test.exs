defmodule StorageTest do
  use ExUnit.Case
  alias Storage.User

  setup do
    {:ok, pid} = Storage.start_link(path: "")
    {:ok, pid: pid}
  end

  test "create user", %{pid: pid} do
    telegram_id = 123

    assert Storage.user(pid, telegram_id) == nil

    assert :ok == Storage.insert_user(pid, telegram_id)

    assert %User{telegram_id: ^telegram_id, rolls_left: 0, seedit_address: nil, credit: 0} =
             Storage.user(pid, telegram_id)

    assert {:error, {:constraint, 'UNIQUE constraint failed: users.telegram_id'}} ==
             Storage.insert_user(pid, telegram_id)

    assert %User{telegram_id: ^telegram_id, rolls_left: 0, seedit_address: nil, credit: 0} =
             Storage.user(pid, telegram_id)
  end

  test "ensure user exists", %{pid: pid} do
    telegram_id = 124
    assert Storage.user(pid, telegram_id) == nil
    assert :ok == Storage.ensure_user_exists(pid, telegram_id)
    assert :ok == Storage.ensure_user_exists(pid, telegram_id)

    assert %User{telegram_id: ^telegram_id, rolls_left: 0, seedit_address: nil, credit: 0} =
             Storage.user(pid, telegram_id)

    # add a roll
    assert :ok = Storage.change_rolls_count(pid, telegram_id, 1)

    assert %User{telegram_id: ^telegram_id, rolls_left: 1, seedit_address: nil, credit: 0} =
             Storage.user(pid, telegram_id)

    # add an address
    address = :crypto.strong_rand_bytes(21)
    assert :ok = Storage.set_seedit_address(pid, telegram_id, address)

    # change credit
    assert :ok = Storage.change_credit(pid, telegram_id, +100)

    # doesn't rewrite
    assert :ok == Storage.ensure_user_exists(pid, telegram_id)

    assert %User{
             telegram_id: ^telegram_id,
             rolls_left: 1,
             seedit_address: ^address,
             credit: 100
           } = Storage.user(pid, telegram_id)
  end

  test "set seedit address", %{pid: pid} do
    telegram_id = 125_123
    address = :crypto.strong_rand_bytes(21)

    assert Storage.user(pid, telegram_id) == nil
    assert :ok = Storage.set_seedit_address(pid, telegram_id, address)
    assert Storage.user(pid, telegram_id) == nil

    assert :ok == Storage.ensure_user_exists(pid, telegram_id)
    assert :ok = Storage.set_seedit_address(pid, telegram_id, address)

    assert %User{
             telegram_id: ^telegram_id,
             rolls_left: 0,
             seedit_address: ^address
           } = Storage.user(pid, telegram_id)
  end

  test "add rolls", %{pid: pid} do
    telegram_id = 125

    # when the user doesn't exist
    assert Storage.user(pid, telegram_id) == nil
    assert :ok = Storage.change_rolls_count(pid, telegram_id, 1)
    assert Storage.user(pid, telegram_id) == nil

    assert :ok == Storage.ensure_user_exists(pid, telegram_id)
    assert %User{telegram_id: ^telegram_id, rolls_left: 0} = Storage.user(pid, telegram_id)

    assert :ok = Storage.change_rolls_count(pid, telegram_id, 20)
    assert %User{telegram_id: ^telegram_id, rolls_left: 20} = Storage.user(pid, telegram_id)

    assert :ok = Storage.change_rolls_count(pid, telegram_id, -10)
    assert %User{telegram_id: ^telegram_id, rolls_left: 10} = Storage.user(pid, telegram_id)

    assert {:error, {:constraint, 'CHECK constraint failed: users'}} =
             Storage.change_rolls_count(pid, telegram_id, -11)

    assert %User{telegram_id: ^telegram_id, rolls_left: 10} = Storage.user(pid, telegram_id)
  end

  test "add credit", %{pid: pid} do
    telegram_id = 121_234

    # when the user doesn't exist
    assert Storage.user(pid, telegram_id) == nil
    assert :ok = Storage.change_credit(pid, telegram_id, +100)
    assert Storage.user(pid, telegram_id) == nil

    assert :ok == Storage.ensure_user_exists(pid, telegram_id)
    assert %User{telegram_id: ^telegram_id, credit: 0} = Storage.user(pid, telegram_id)

    assert :ok = Storage.change_credit(pid, telegram_id, +70)
    assert %User{telegram_id: ^telegram_id, credit: 70} = Storage.user(pid, telegram_id)

    assert :ok = Storage.change_credit(pid, telegram_id, -10)
    assert %User{telegram_id: ^telegram_id, credit: 60} = Storage.user(pid, telegram_id)
  end

  test "multiple users", %{pid: pid} do
    telegram_ids = 200..300

    users =
      Enum.map(telegram_ids, fn telegram_id ->
        %User{
          telegram_id: telegram_id,
          rolls_left: :rand.uniform(10),
          seedit_address: :crypto.strong_rand_bytes(21),
          credit: :rand.uniform(100)
        }
      end)

    Enum.each(users, fn user ->
      assert :ok == Storage.insert_user(pid, user.telegram_id)
      assert :ok == Storage.change_rolls_count(pid, user.telegram_id, user.rolls_left)
      assert :ok == Storage.set_seedit_address(pid, user.telegram_id, user.seedit_address)
      assert :ok == Storage.change_credit(pid, user.telegram_id, user.credit)
    end)

    pid
    |> Storage.users()
    |> Enum.zip(users)
    |> Enum.each(fn {fetched_user, expected_user} ->
      assert fetched_user == expected_user
    end)
  end

  test "pool size", %{pid: pid} do
    assert 0 = Storage.pool_size(pid)

    assert :ok = Storage.change_pool_size(pid, +10000)
    assert 10000 = Storage.pool_size(pid)

    assert :ok = Storage.change_pool_size(pid, +10000)
    assert 20000 = Storage.pool_size(pid)

    assert :ok = Storage.reset_pool_size(pid, 15)
    assert 15 = Storage.pool_size(pid)

    assert {:error, :overdraft} = Storage.change_pool_size(pid, -20)
    assert 15 = Storage.pool_size(pid)
  end

  test "roll pic", %{pid: pid} do
    bot_id = "1234:ausydft"
    refute Storage.roll_pic_file_id(pid, bot_id)

    # set once
    assert :ok == Storage.set_roll_pic(pid, bot_id, "qwer1")
    assert "qwer1" == Storage.roll_pic_file_id(pid, bot_id)

    # set twice
    assert :ok == Storage.set_roll_pic(pid, bot_id, "qwer2")
    assert "qwer2" == Storage.roll_pic_file_id(pid, bot_id)
  end

  test "initialized rooms", %{pid: pid} do
    phone_number1 = "18273645"
    phone_number2 = "1237864"

    room_id1 = -18_237_645
    room_id2 = -29_834_756
    room_id3 = -23_847_657

    assert [] == Storage.initialized_rooms(pid, phone_number1)
    assert [] == Storage.initialized_rooms(pid, phone_number2)

    assert :ok == Storage.insert_initialized_room(pid, phone_number1, room_id1)
    assert :ok == Storage.insert_initialized_room(pid, phone_number1, room_id2)

    assert {:error,
            {:constraint,
             'UNIQUE constraint failed: initialized_rooms.phone_number, initialized_rooms.room_id'}} ==
             Storage.insert_initialized_room(pid, phone_number1, room_id2)

    assert Enum.sort([room_id2, room_id1]) ==
             Enum.sort(Storage.initialized_rooms(pid, phone_number1))

    assert [] == Storage.initialized_rooms(pid, phone_number2)

    assert :ok == Storage.delete_initialized_room(pid, phone_number1, room_id3)
    assert :ok == Storage.delete_initialized_room(pid, phone_number1, room_id2)

    assert [room_id1] == Storage.initialized_rooms(pid, phone_number1)

    assert :ok == Storage.insert_initialized_room(pid, phone_number2, room_id1)
    assert :ok == Storage.insert_initialized_room(pid, phone_number2, room_id2)
    assert :ok == Storage.insert_initialized_room(pid, phone_number2, room_id3)

    assert [room_id1] == Storage.initialized_rooms(pid, phone_number1)

    assert Enum.sort([room_id1, room_id2, room_id3]) ==
             Enum.sort(Storage.initialized_rooms(pid, phone_number2))

    assert :ok == Storage.reset_initialized_rooms(pid, phone_number2)

    assert [room_id1] == Storage.initialized_rooms(pid, phone_number1)
    assert [] == Storage.initialized_rooms(pid, phone_number2)
  end
end
