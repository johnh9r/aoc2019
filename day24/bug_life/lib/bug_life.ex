defmodule BugLife do
  @moduledoc """
  simulate population growth/decline of bugs in limited area
  """

  import Bitwise

  @empty "."
  @bug "#"

  @doc """
  (part 1)
  """
  @spec score_first_recurring_map(String.t()) :: integer
  def score_first_recurring_map(initial_map) do
    {map, map_width, map_height} =
      initial_map
      |> parse_map()

    score = step_generation(map, map_width, map_height, %{})
    
    score
  end

  @spec step_generation(MapSet.t(), integer, integer, map) :: integer
  defp step_generation(map, map_w, map_h, history) do
    # NOTE score uniquely characterises map constellation (allowing easy duplicate detection)
    score = score_population(map, map_w, map_h)
            |> IO.inspect(label: "\nscore")

    {prev_scored_map, history} =
      Map.get_and_update(history, score, fn old_val -> {old_val, map} end)

    case prev_scored_map do
      nil ->
        next_map = generate_next_map(map, map_w, map_h)
        step_generation(next_map, map_w, map_h, history)

      _ ->
        score
    end
  end

  @spec generate_next_map(MapSet.t(), integer, integer) :: MapSet.t()
  defp generate_next_map(map, map_w, map_h) do
    neighbourhood = count_neighbours_by_sliding_window(map, map_w, map_h)
    # IO.inspect({map, neighbourhood}, label: "\ncurr")
    # bug:  dies (becoming an empty space) unless there is exactly one bug adjacent to it
    # space:  becomes infested with a bug if exactly one or two bugs are adjacent to it
    0..(map_h-1)
    |> Enum.reduce(
      MapSet.new(),
      fn y, acc_outer ->
        0..(map_w-1)
        |> Enum.reduce(
          MapSet.new(),
          fn x, acc_inner ->
            case {MapSet.member?(map, {x,y}), Map.fetch!(neighbourhood, {x,y})} do
              {true, 1} ->
                # bug w/ one neighbour survives to next generation
                MapSet.put(acc_inner, {x,y})
              {true, _} ->
                # other bugs not propagated to next generation (died off)
                acc_inner
              {false, n} when n in [1, 2] ->
                # empty space w/ one or two neighbouring bugs becomes populated
                MapSet.put(acc_inner, {x,y})
              {false, _} ->
                # other empty space remains unchanged
                acc_inner
            end
          end
        )
        |> MapSet.union(acc_outer)
      end
    )    
    # |> IO.inspect(label: "\nnext")

  end

  @doc """

  .#.
  ###
  .#.
 
  iex> BugLife.count_neighbours_by_sliding_window(MapSet.new([{1,0}, {0,1},{1,1},{2,1}, {1,2}]), 3, 3)
  %{{0,0}=>2, {1,0}=>1, {2,0}=>2,  {0,1}=>1, {1,1}=>4, {2,1}=>1,  {0,2}=>2, {1,2}=>1, {2,2}=>2}
  """
  @spec count_neighbours_by_sliding_window(MapSet.t(), integer, integer) :: %{required({integer, integer}) => integer} 
  def count_neighbours_by_sliding_window(map, map_w, map_h) do
    0..(map_h-1)
    |> Enum.reduce(
      %{},
      fn y, acc_outer ->
        0..(map_w-1)
        |> Enum.reduce(
          %{},
          fn x, acc_inner ->
            # non-existent tiles (over edges) are nil, so default to zero
            # neighbours: N, E, S, W
            count =
              (MapSet.member?(map, {x+0,y-1}) && 1 || 0) +
              (MapSet.member?(map, {x+1,y+0}) && 1 || 0) +
              (MapSet.member?(map, {x+0,y+1}) && 1 || 0) +
              (MapSet.member?(map, {x-1,y+0}) && 1 || 0)
            Map.put(acc_inner, {x,y}, count)
          end
        )
        |> Map.merge(acc_outer)
      end
    )    
  end

  @doc """
  iex> BugLife.score_population(MapSet.new([{0,3}, {1,4}]), 5, 5)
  2097152+32768
  """
  @spec score_population(MapSet.t(), integer, integer) :: integer
  def  score_population(map, map_w, map_h) do
    0..(map_h-1)
    |> Enum.reduce(
      0,
      fn y, acc ->
        0..(map_w-1)
        |> Enum.reduce(
          0,
          fn x, acc_inner ->
            case MapSet.member?(map, {x,y}) do
              true ->
                acc_inner + Bitwise.bsl(1, y * map_w + x)
              _ ->
                acc_inner
            end
          end
        )
        |> Kernel.+(acc)
      end
    )    
  end

  @doc """
  iex> BugLife.parse_map(~s{
  ...>.#..#
  ...>.....
  ...>#####
  ...>....#
  ...>...##
  ...>})
  {MapSet.new([{1,0},{4,0}, {0,2},{1,2},{2,2},{3,2},{4,2}, {4,3}, {3,4},{4,4}]), 5, 5}
  """
  @spec parse_map(String.t()) :: {MapSet.t(), integer, integer}
  def parse_map(bug_map_s) do
    map_scan_lines =
      bug_map_s
      |> String.split()

    map_height = length(map_scan_lines)

    map_width =
      map_scan_lines
      |> List.first()
      |> String.length()

    {bug_map, _} =
      map_scan_lines
      |> Enum.reduce(
        {MapSet.new(), 0},
        fn scan_line, {bug_set, y} ->
          {mapped_scan_line, _, _} =
            scan_line |> String.split(~r//, trim: true)
            |> Enum.reduce(
              {bug_set, y, 0},
              fn loc, {bug_set, y, x} ->
                case loc do
                  @bug ->
                    {MapSet.put(bug_set, {x, y}), y, x + 1 }
                  @empty ->
                    {bug_set, y, x + 1}
                end
              end
            )

          {MapSet.union(bug_set, mapped_scan_line), y + 1}
        end
      )

    {bug_map, map_width, map_height}
  end
end
