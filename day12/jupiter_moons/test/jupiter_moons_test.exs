defmodule JupiterMoonsTest do
  use ExUnit.Case
  doctest JupiterMoons, only: [distinct_pairs: 1]

  setup do
    # Io, Europa, Ganymede, and Callisto
    #
    # <x=17, y=5, z=1>
    # <x=-2, y=-8, z=8>
    # <x=7, y=-6, z=14>
    # <x=1, y=-10, z=4>

    # {x, y, z}
    my_initial_positions = %{
      io: {17, 5, 1},
      europa: {-2, -8, 8},
      ganymede: {7, -6, 14},
      callisto: {1, -10, 4}
    }

    # from problem definition
    initial_velocities = %{
      io: {0, 0, 0},
      europa: {0, 0, 0},
      ganymede: {0, 0, 0},
      callisto: {0, 0, 0}
    }

    [
      initial_positions: my_initial_positions,
      initial_velocities: initial_velocities,
      num_time_steps: 1_000
    ]
  end

  @tag :challenge_pt1
  test "(part 1) processes personal challenge data correctly", context do
    assert JupiterMoons.calc_total_energy(
      context[:initial_positions],
      context[:initial_velocities],
      context[:num_time_steps]
    ) == 9_876
  end
end
