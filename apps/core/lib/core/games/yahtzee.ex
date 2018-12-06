defmodule Core.Games.Yahtzee do
  @moduledoc """
  Models a simplified game of yahtzee.
  """

  @type dice :: [1..6, ...]
  @type reward :: :pool | :"400" | :"200" | :extra_roll
  @type result :: {:win, reward, dice} | {:lose, dice}

  @spec play :: result
  def play do
    dice = Enum.map(1..5, fn _ -> :rand.uniform(6) end)

    case Enum.sort(dice) do
      # five of a kind -> win pool
      [d, d, d, d, d] -> {:win, :pool, dice}
      # four of a kind -> win 400 TRX
      [d, d, d, d, _] -> {:win, :"400", dice}
      [d, d, d, _, d] -> {:win, :"400", dice}
      [d, d, _, d, d] -> {:win, :"400", dice}
      [d, _, d, d, d] -> {:win, :"400", dice}
      [_, d, d, d, d] -> {:win, :"400", dice}
      # large straight (5 Dice in a row 1-5 or 2-6) -> win 200 TRX
      [1, 2, 3, 4, 5] -> {:win, :"200", dice}
      [2, 3, 4, 5, 6] -> {:win, :"200", dice}
      # small straight (4 Dice in a row 1-4, 2-5, 3-6) -> win an extra roll
      [1, 2, 3, 4, _] -> {:win, :extra_roll, dice}
      [_, 1, 2, 3, 4] -> {:win, :extra_roll, dice}
      [2, 3, 4, 5, _] -> {:win, :extra_roll, dice}
      [_, 2, 3, 4, 5] -> {:win, :extra_roll, dice}
      [3, 4, 5, 6, _] -> {:win, :extra_roll, dice}
      [_, 3, 4, 5, 6] -> {:win, :extra_roll, dice}
      # full house (3 of the same dice and 2 of the same dice) -> win an extra roll
      [a, a, a, b, b] -> {:win, :extra_roll, dice}
      [a, a, b, b, b] -> {:win, :extra_roll, dice}
      # otherwise lose
      _ -> {:lose, dice}
    end
  end
end
