defmodule Asteroids do
  @moduledoc """
  choose asteroid coordinates best suited to monitoring as many other asteroids as possible

  ##  notes
  * {0, 0} is top-left corner of map
  * choosing {x, y} generally (as per problem definition)
  * assuming map to be rectangular
  """

  @asteroid "#"
  @space    "."

  @doc """
  iex> Asteroids.calc_optimum_monitoring_location(~s/
  ...>.#..#
  ...>.....
  ...>#####
  ...>....#
  ...>...##
  ...>/)
  {3, 4}

  """
  @spec calc_optimum_monitoring_location(String.t()) :: {integer, integer}
  def calc_optimum_monitoring_location(asteroid_map_s) do
    {asteroids, map_width, map_height} =
      asteroid_map_s
      |> parse_map()

    asteroids
    |> MapSet.to_list()
    |> Enum.map(fn candidate_loc -> count_360deg_scan(asteroids, map_width, map_height, candidate_loc) end)
    |> Enum.max_by(fn {{_, _}, count} -> count end)
  end

  # {1,0} <!< must not skip from (3,4) _over_ (2,2) directly to (1,0) at incline (-2,-4) vs (-1,-2)
  #
  # {4,0}
  # {0,2}
  # {1,2}
  # {2,2}
  # {3,2}
  # {4,2}
  # {4,3}
  # {4,4}

  @doc """
  iex> Asteroids.count_360deg_scan(MapSet.new([{1,0},{4,0}, {0,2},{1,2},{2,2},{3,2},{4,2}, {4,3}, {3,4},{4,4}]), 5, 5, {3, 4})
  {{3,4}, 8}
  """
  @spec count_360deg_scan(MapSet.t(), integer, integer, {integer, integer}) :: {{integer, integer}, integer}
  def count_360deg_scan(asteroids, width, height, {cand_x, cand_y}) do
    # brute-force check all conceivable inclines (first quadrant plus x- and y-mirroring)
    # single tracer step stays within map boundaries at least in best case scenario of candidate {0,0}
    visible_asteroids_in_all_directions =
      for step_x <- Range.new(0, width - 1), step_y <- Range.new(0, height - 1), Integer.gcd(step_x, step_y) == 1 do
        # four directions (quadrants)
        [{1, 1}, {-1, 1}, {1, -1}, {-1, -1}]
        |> Enum.reduce(
          MapSet.new(),
          fn {sign_x, sign_y}, acc ->
            MapSet.union(acc, enumerate_quadrant(asteroids, width, height, {cand_x, cand_y}, {sign_x * step_x, sign_y * step_y}) )
          end
        )
      end
      |> Enum.reduce(MapSet.new(), fn ms, acc-> MapSet.union(acc, ms) end)

    {{cand_x, cand_y}, visible_asteroids_in_all_directions |> MapSet.size()}
  end

  @doc """
  """
  @spec enumerate_quadrant(MapSet.t(), integer, integer, {integer, integer}, {integer, integer}) :: MapSet.t()
  def enumerate_quadrant(_asteroids, _width, _height, {_cand_x, _cand_y}, {0, 0}), do: MapSet.new()
  def enumerate_quadrant(asteroids, width, height, {cand_x, cand_y}, {step_x, step_y}) do
    {visible_asteroids, _} =
      calc_scan_points(width, height, {cand_x, cand_y}, {step_x, step_y})
      |> Enum.reduce(
        {MapSet.new(), MapSet.new()},
        fn check_loc, {visible_loc, invisible_loc} = _acc ->
          case {MapSet.member?(asteroids, check_loc), MapSet.size(visible_loc) == 0} do
            {true, true} ->
              # saw other asteroid (first one)
              {MapSet.put(visible_loc, check_loc), invisible_loc}
              # saw other asteroid (obscured)
            {true, _} ->
              {visible_loc, MapSet.put(invisible_loc, check_loc)}
            {false, _} ->
              # nothing to see here
              {visible_loc, invisible_loc}
          end
        end
      )

    visible_asteroids
  end

  @doc """
  """
  @spec calc_scan_points(integer, integer, {integer, integer}, {integer, integer}) :: [{integer, integer}]
  def calc_scan_points(_width, _height, {cand_x, _cand_y}, {_step_x, _step_y}) when cand_x < 0, do: []
  def calc_scan_points(_width, _height, {_cand_x, cand_y}, {_step_x, _step_y}) when cand_y < 0, do: []
  def calc_scan_points(width, _height, {cand_x, _cand_y}, {_step_x, _step_y}) when cand_x > width, do: []
  def calc_scan_points(_width, height, {_cand_x, cand_y}, {_step_x, _step_y}) when cand_y > height, do: []
  def calc_scan_points(width, height, cand_loc, {step_x, step_y}) do
    # order is significant (tracer ray radiating outward)
    # in extremis, e.g. candidate {0,0} and incline {1,0}, must consider up to "width" steps
    Stream.iterate(
      cand_loc,
      fn {x, y} -> {x + step_x, y + step_y} end
    )
    |> Enum.take_while(
      fn {x, y} -> 0 <= x && x < width && 0 <= y && y < height end
    )
    # candidate location itself
    |> Enum.drop(1)
  end

  @doc """
  iex> Asteroids.parse_map(String.split(~s/
  ...>.#..#
  ...>.....
  ...>#####
  ...>....#
  ...>...##
  ...>/))
  MapSet.new([{1,0},{4,0}, {0,2},{1,2},{2,2},{3,2},{4,2}, {4,3}, {3,4},{4,4}])
  """
  @spec parse_map(String.t()) :: {MapSet.t(), integer, integer}
  def parse_map(asteroid_map_s) do
    map_scan_lines =
      asteroid_map_s
      |> String.split()

    map_height = length(map_scan_lines)

    map_width =
      map_scan_lines
      |> List.first()
      |> String.length()

    {asteroid_map, _} =
      map_scan_lines
      |> Enum.reduce(
        {MapSet.new(), 0},
        fn scan_line, {ast_set, y} ->
          {mapped_scan_line, _, _} =
            scan_line |> String.split(~r//, trim: true)
            |> Enum.reduce(
              {ast_set, y, 0},
              fn loc, {ast_set, y, x} ->
                case loc do
                  @asteroid ->
                    {
                      MapSet.put(ast_set, {x, y}),
                      y,
                      x + 1
                    }
                  @space -> {ast_set, y, x + 1}
                  x -> raise "unknown object: #{x}"
                end
              end
            )

          {MapSet.union(ast_set, mapped_scan_line), y + 1}
        end
      )

    {asteroid_map, map_width, map_height}
  end
end
