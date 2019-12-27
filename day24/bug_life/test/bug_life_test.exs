defmodule BugLifeTest do
  use ExUnit.Case
  doctest BugLife, only: []

  setup do
    my_map =
      """
      #####
      ...##
      #..#.
      #....
      #...#
      """

    [population_map: my_map]
  end

  @tag :challenge_pt1
  test "(part 1) correctly processes personal challenge", context do
    assert BugLife.score_first_recurring_map(context[:population_map]) == 18_404_913 
  end
end
