defmodule AsteroidsTest do
  use ExUnit.Case
  doctest Asteroids, only: [count_360deg_scan: 4] #[calc_optimum_monitoring_location: 1]

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
  test "(part 2) processes personal challenge correctly", _context do
    assert false
    # assert Asteroids.calc_optimum_monitoring_location(context[:asteroid_map]) == {0,0}
  end
end
