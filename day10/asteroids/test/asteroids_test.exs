defmodule AsteroidsTest do
  use ExUnit.Case
  doctest Asteroids, only: [calc_sweep_angles_for_first_quadrant: 2]

  setup do
    my_asteroid_map = """
      .##.#.#....#.#.#..##..#.#.
      #.##.#..#.####.##....##.#.
      ###.##.##.#.#...#..###....
      ####.##..###.#.#...####..#
      ..#####..#.#.#..#######..#
      .###..##..###.####.#######
      .##..##.###..##.##.....###
      #..#..###..##.#...#..####.
      ....#.#...##.##....#.#..##
      ..#.#.###.####..##.###.#.#
      .#..##.#####.##.####..#.#.
      #..##.#.#.###.#..##.##....
      #.#.##.#.##.##......###.#.
      #####...###.####..#.##....
      .#####.#.#..#.##.#.#...###
      .#..#.##.#.#.##.#....###.#
      .......###.#....##.....###
      #..#####.#..#..##..##.#.##
      ##.#.###..######.###..#..#
      #.#....####.##.###....####
      ..#.#.#.########.....#.#.#
      .##.#.#..#...###.####..##.
      ##...###....#.##.##..#....
      ..##.##.##.#######..#...#.
      .###..#.#..#...###..###.#.
      #..#..#######..#.#..#..#.#
      """

    [asteroid_map: my_asteroid_map]
  end

  @tag :challenge_pt1
  test "(part 1) processes personal challenge correctly", context do
    assert Asteroids.calc_optimum_monitoring_location(context[:asteroid_map]) == {{19, 14}, 274}
  end

  @tag :challenge_pt2
  test "(part 2) processes personal challenge correctly", context do
    Asteroids.enumerate_blasted_asteroids(context[:asteroid_map], {19, 14})
    |> Enum.take(200)
    |> List.last()
    |> (fn {x, y} -> 100 * x + y end).()
    |> Kernel.==(100 * 3 + 5)
    |> ExUnit.Assertions.assert()
  end
end
