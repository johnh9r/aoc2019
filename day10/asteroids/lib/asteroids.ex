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
    map_scan_lines =
      asteroid_map_s
      |> String.split()

    map_width = map_scan_lines |> List.first() |> String.length()

    map_height = length(map_scan_lines)

    asteroids =
      map_scan_lines
      |> parse_map()

    asteroids
    |> MapSet.to_list()
    |> Enum.map(fn candidate_loc -> count_360deg_scan(asteroids, map_width, map_height, candidate_loc) end)
    |> IO.inspect()
    |> Enum.max_by(fn {{_, _}, count} -> count end)
  end

  @doc """
  iex> Asteroids.count_360deg_scan(MapSet.new([{1,0},{4,0}, {0,2},{1,2},{2,2},{3,2},{4,2}, {4,3}, {3,4},{4,4}]), {3, 4})
  {{3,4}, 8}
  """
  @spec count_360deg_scan(MapSet.t(), integer, integer, {integer, integer}) :: {{integer, integer}, integer}
  def count_360deg_scan(asteroids, width, height, {x, y}) do
    {{-1,-3}, 7}
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
  @spec parse_map([String.t()]) :: map
  def parse_map(scan_lines) do
    {asteroid_map, _} =
      scan_lines
      |> Enum.reduce(
        {MapSet.new(), 0},
        fn scan_line, {ast_set, y} ->
          {mapped_scan_line, _, _} =
            scan_line |> String.split(~r//, trim: true)
            |> Enum.reduce(
              {ast_set, y, 0},
              fn loc, {ast_set, y, x} ->
                case loc do
                  # asteroid
                  "#" ->
                    {
                      MapSet.put(ast_set, {x, y}),
                      y,
                      x + 1
                    }
                  # space
                  "." -> {ast_set, y, x + 1}
                  x -> raise "unknown object: #{x}"
                end
              end
            )

          {MapSet.union(ast_set, mapped_scan_line), y + 1}
        end
      )

    asteroid_map
  end
end
