defmodule TractorBeam.WorldAffairs do
  @moduledoc """
  """

  @spec initialize(Keyword.t()) :: pid
  def initialize(initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @spec get_final_state() :: Keyword.t()
  def get_final_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  @spec handle_input_request() :: integer
  def handle_input_request() do
    state = Agent.get(__MODULE__, fn state -> state end)
    [next_coord | remaining_coords] = Keyword.fetch!(state, :xy)
    Agent.update(__MODULE__, fn state -> Keyword.merge(state, [xy: remaining_coords]) end)
    next_coord
  end

  @spec handle_output_request(integer) :: :ok
  def handle_output_request(value) do
    Agent.update(__MODULE__, fn state -> Keyword.merge(state, [affected: value]) end)
  end

  @spec set_drone_coordinates(integer, integer) :: :ok
  def set_drone_coordinates(x, y) do
    Agent.update(__MODULE__, fn state -> Keyword.merge(state, [xy: [x, y], affected: false]) end)
  end

end


defmodule TractorBeam do
  @moduledoc """
  ## notes
  * coordinate system with {0,0} = top/left and both x and y growing into positive range
  * assuming no holes or outliers in tractor beam field
  """

  alias TractorBeam.WorldAffairs

  # from problem definition
  @x_max 49
  @y_max 49

  # guestimates -- excessively large number entail long drone-based probing duration
  @x_max_pt2 1279
  @y_max_pt2 767

  @doc """
  part 2
  """
  @spec calc_nearest_xy_of_enclosed_square([integer], integer) :: {integer, integer}
  def calc_nearest_xy_of_enclosed_square(_firmware, square_dim) when square_dim < 1, do: raise ArgumentError

  def calc_nearest_xy_of_enclosed_square(firmware, square_dim) do
    {:ok, _pid} = WorldAffairs.initialize([])
    tractor_beam_map =
      map_tractor_beam(firmware, @x_max_pt2, @y_max_pt2)

    render_patchy_map(tractor_beam_map, @x_max_pt2, @y_max_pt2) |> (fn screen -> ["\n\n" | screen] end).() |> IO.write()


    # span of beam is contiguous horizontally w/o holes or outliers, so characterised by two extremes
    rows =
      0..@y_max_pt2
      |> Enum.map(
        fn y ->
          {{min_x, _min_y}, {max_x, _max_y}} =
            tractor_beam_map
            |> Enum.filter(fn {_cand_x, cand_y} -> cand_y == y end)
            |> Enum.min_max(fn -> {{-1, nil}, {-2, nil}} end)
          {min_x, max_x}
        end
      )
      |> IO.inspect(label: "\nrows")

    # NOTE  max_(-2) - min_(-1) + 1 = extent_0 (both horizontally and vertically)

    # span of beam is contiguous vertically w/o holes or outliers, so characterised by two extremes
    columns =
      0..@x_max_pt2
      |> Enum.map(
        fn x ->
          {{_min_x, min_y}, {_max_x, max_y}} =
            tractor_beam_map
            |> Enum.filter(fn {cand_x, _cand_y} -> cand_x == x end)
            |> Enum.min_max(fn -> {{nil, -1}, {nil, -2}} end)
          {min_y, max_y}
        end
      )
      |> IO.inspect(label: "\ncols")

    # fit vertical square edge first, since beam is flat (Y) but wide (X)
    columns
    |> Enum.with_index()
    |> Enum.filter(fn {{y_min, y_max}, _x} -> (y_max - y_min) + 1 >= square_dim end)
    |> IO.inspect(label: "\ncand")
    |> Enum.reduce(
      [],
      fn {{_y_min, y_max}, x_cand}, acc ->
        # anchor bottom left corner;  definitely high enough, but check width at top
        {_x_min, x_max} = Enum.at(rows, y_max - square_dim + 1)
        case x_cand + square_dim - 1 <= x_max do
          true -> acc ++ [{x_cand, y_max - square_dim + 1}]
          _ -> acc
        end
      end
    )
    |> IO.inspect(label: "\nresults")
    |> List.first()
    |> (fn {x, y}-> 10_000 * x + y end).()
  end

  @doc """
  part 1

  TractorBeam.count_affected_positions(unavailable_firmware)
  #.........
  .#........
  ..##......
  ...###....
  ....###...
  .....####.
  ......####
  ......####
  .......###
  ........##
  27
  """
  @spec count_affected_positions([integer]) :: integer
  def count_affected_positions(firmware) do
    {:ok, _pid} = WorldAffairs.initialize([])
    map_tractor_beam(firmware, @x_max, @y_max)
    |> MapSet.size()
  end

  # XXX binary search for x_min, x_max per given y (RLE of beam)
  @spec map_tractor_beam([integer], integer, integer) :: MapSet.t()
  defp map_tractor_beam(firmware, x_max, y_max) do
    0..y_max
    |> Enum.reduce(
      MapSet.new(),
      fn y, outer_acc ->
        0..x_max
        |> Enum.reduce(
          outer_acc,
          fn x, inner_acc ->
            case x < y || x > 4*y do
              true ->
                # empirical optimisation: no positions affected below diagonal
                inner_acc
              _ ->
                WorldAffairs.set_drone_coordinates(x, y)
                run_single_use_drone(firmware)
                state = WorldAffairs.get_final_state()
                case Keyword.fetch!(state, :affected) do
                  1 -> MapSet.put(inner_acc, {x,y})
                  _ -> inner_acc
                end
            end
          end
        )
      end
    )
  end

  @spec run_single_use_drone([integer]) :: :ok
  defp run_single_use_drone(firmware) do
    task = Task.async(
      IntCodeBoost,
      :execute,
      [
        firmware,
        # both (in/out) from perspective of IntCode machine
        &WorldAffairs.handle_input_request/0,
        &WorldAffairs.handle_output_request/1
      ]
    )

    Task.await(task, :infinity)
    :ok
  end

  @spec render_patchy_map(MapSet.t(), integer, integer) :: iodata
  defp render_patchy_map(tiles, max_x, max_y) do
    background =
      for y <- 0..max_y, x <- 0..max_x do
        {{x, y}, "."}
      end
      |> Enum.into(%{})

    tiles_map =
      tiles
      |> Enum.reduce(%{}, fn {x,y}, acc -> Map.put(acc, {x,y}, "#") end)

    background
    |> Map.merge(tiles_map)
    # use y-coordinate as dominant sort key in order to form scan lines
    |> Enum.group_by(fn {{_x, y}, _} -> y end)
    |> Enum.sort_by(fn {k, _v}-> k end)
    |> Enum.into(
      [],
      fn {_group_key_y, tiles} ->
        tiles
        |> Enum.sort_by(fn {{x, _y}, _} -> x end)
        |> Enum.map(fn {{_x,_y}, tile_ch} -> tile_ch end)
      end
    )
    |> Enum.intersperse("\n")
  end
end
