defmodule Core.Games.Yahtzee do
  @moduledoc """
  Models a simplified game of yahtzee.
  """

  @type dice :: [1..6, ...]
  @type reward :: :pool | :large_straight | :four_of_kind | :extra_roll
  @type result :: {:win, reward, dice} | {:lose, dice}

  @spec play :: result
  def play do
    dice = Enum.map(1..5, fn _ -> :rand.uniform(6) end)

    case Enum.sort(dice) do
      [d, d, d, d, d] -> {:win, :pool, dice}
      [d, d, d, d, _] -> {:win, :four_of_kind, dice}
      [d, d, d, _, d] -> {:win, :four_of_kind, dice}
      [d, d, _, d, d] -> {:win, :four_of_kind, dice}
      [d, _, d, d, d] -> {:win, :four_of_kind, dice}
      [_, d, d, d, d] -> {:win, :four_of_kind, dice}
      [1, 2, 3, 4, 5] -> {:win, :large_straight, dice}
      [2, 3, 4, 5, 6] -> {:win, :large_straight, dice}
      [1, 2, 3, 4, _] -> {:win, :extra_roll, dice}
      [1, 2, 2, 3, 4] -> {:win, :extra_roll, dice}
      [1, 2, 3, 3, 4] -> {:win, :extra_roll, dice}
      [_, 1, 2, 3, 4] -> {:win, :extra_roll, dice}
      [2, 3, 4, 5, _] -> {:win, :extra_roll, dice}
      [2, 3, 3, 4, 5] -> {:win, :extra_roll, dice}
      [2, 3, 4, 4, 5] -> {:win, :extra_roll, dice}
      [_, 2, 3, 4, 5] -> {:win, :extra_roll, dice}
      [3, 4, 5, 6, _] -> {:win, :extra_roll, dice}
      [3, 4, 4, 5, 6] -> {:win, :extra_roll, dice}
      [3, 4, 5, 5, 6] -> {:win, :extra_roll, dice}
      [_, 3, 4, 5, 6] -> {:win, :extra_roll, dice}
      [a, a, a, b, b] -> {:win, :extra_roll, dice}
      [a, a, b, b, b] -> {:win, :extra_roll, dice}
      _ -> {:lose, dice}
    end
  end
end
