defmodule RobotEvac.WorldAffairs do
  @scaffold ?#
  @space ?.

  @robot_north ?^
  @robot_south ?v
  @robot_east ?<
  @robot_west ?>

  @robot_lost ?X

  @newline 0x0a

  @spec initialize(Keyword.t()) :: pid
  def initialize(initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @spec get_final_state() :: Keyword.t()
  def get_final_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  @spec handle_input_request() :: {integer}
  def handle_input_request() do
    # restore context to answer question
    # TODO
    raise "no input required for first part"
  end

  @spec handle_output_request(integer) :: :ok
  def handle_output_request(value) do
    # restore context to change world
    Agent.update(
      __MODULE__,
      fn state ->
        tiles = Keyword.fetch!(state, :tiles)
        x = Keyword.fetch!(state, :x)
        y = Keyword.fetch!(state, :y)

        update =
          case value do
            # <<@newline::8>> -> [x: 0, y: y+1]
            # <<@space::8>> -> [tiles: Map.put(tiles, {x,y}, "."), x: x+1]
            # <<@scaffold::8>> -> [tiles: Map.put(tiles, {x,y}, "#"), x: x+1]
            # <<@robot_north::8>> -> [tiles: Map.put(tiles, {x,y}, "^"), x: x+1]
            # <<@robot_south::8>> -> [tiles: Map.put(tiles, {x,y}, "v"), x: x+1]
            # <<@robot_east::8>> ->  [tiles: Map.put(tiles, {x,y}, "<"), x: x+1]
            # <<@robot_west::8>> ->  [tiles: Map.put(tiles, {x,y}, ">"), x: x+1]
            # <<@robot_lost::8>> -> [tiles: Map.put(tiles, {x,y}, "X"), x: x+1]

            @newline -> [x: 0, y: y+1]

            @space -> [tiles: Map.put(tiles, {x,y}, "."), x: x+1]
            @scaffold -> [tiles: Map.put(tiles, {x,y}, "#"), x: x+1]

            @robot_north -> [tiles: Map.put(tiles, {x,y}, "^"), x: x+1]
            @robot_south -> [tiles: Map.put(tiles, {x,y}, "v"), x: x+1]
            @robot_east ->  [tiles: Map.put(tiles, {x,y}, "<"), x: x+1]
            @robot_west ->  [tiles: Map.put(tiles, {x,y}, ">"), x: x+1]

            @robot_lost -> [tiles: Map.put(tiles, {x,y}, "X"), x: x+1]
          end

          Keyword.merge(state, update)
      end
    )
  end
end

defmodule RobotEvac do
  @moduledoc """
  evacuate stranded robots from scaffolding exterior to spaceship;
  abuse vacuum robot (w/ high-power LED) as scout;

  ## notes
  * coordinate system w/ (x, y) = (0, 0) = top/left and coordinates growing into positive range
  * assuming rectangular map without holes
  """

  @type tiles_t :: %{required({integer, integer}) => String.t()}

  alias RobotEvac.WorldAffairs

  @doc """
  find all intersection points on scaffolding, then calculate sum of products of their coordinates
  # iex> RobotEvac.sum_intersection_coordinates(firmware)
  # 76
  """
  @spec sum_intersection_coordinates([integer]) :: integer
  def sum_intersection_coordinates(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      tiles: %{},
      x: 0,
      y: 0
    )

    run_robot(firmware)

    state = WorldAffairs.get_final_state()
    Keyword.fetch!(state, :tiles)
    # |> Enum.group_by(fn {{x,y}, _}-> y end)
    # |> Enum.sort()
    # |> IO.inspect(label: "\nscaffolding", limit: :infinity)
    |> detect_intersections()
    # |> IO.inspect(label: "\nxs")
    |> Enum.reduce(0, fn {x, y}, acc -> acc + x * y end
    )
  end

  # only considering horizontal/vertical (i.e. not diagonal)
  @spec detect_intersections(tiles_t) :: [{integer, integer}]
  def detect_intersections(tiles) do
    enumerate_sliding_windows_without_robot(tiles)
    |> Enum.reduce(
      [],
      fn {{x_ctr,y_ctr}, above3, centre3, below3}, acc ->
        case {above3, centre3, below3} do
          {[_, "#", _], ["#", "#", "#"], [_, "#", _]} -> [{x_ctr, y_ctr} | acc]
          _ -> acc
        end
      end
    )
  end

  # XXX define custom type (shorthand)
  @spec enumerate_sliding_windows_without_robot(tiles_t) :: {{integer, integer}, [String.t()], [String.t()], [String.t()]}
  def enumerate_sliding_windows_without_robot(tiles) do
    # not so much sliding as jumping around wildly, but ... meh
    # TODO optimise
    tiles
    |> without_robot()
    |> Enum.map(
      # non-existent tiles (over edges) are nil, but OK, since
      # pattern match elsewhere makes positive assertions about all rows and columns
      fn {{x,y}, t} ->
        {
          {x, y},
          [Map.get(tiles, {x-1,y-1}), Map.get(tiles, {x+0,y-1}), Map.get(tiles, {x+1,y-1})],
          [Map.get(tiles, {x-1,y+0}), Map.get(tiles, {x+0,y+0}), Map.get(tiles, {x+1,y+0})],
          [Map.get(tiles, {x-1,y+1}), Map.get(tiles, {x+0,y+1}), Map.get(tiles, {x+1,y+1})]
        }
      end
    )
  end

  @spec without_robot(tiles_t) :: tiles_t
  defp without_robot(tiles) do
    tiles
    |> Enum.map(
      fn {k, v} ->
        # XXX better notation
        # robot is always on scaffolding (unless lost)
        case v do
          "^" -> {k, "#"}
          "v" -> {k, "#"}
          "<" -> {k, "#"}
          ">" -> {k, "#"}
          _ -> {k, v}
        end
      end
    )
  end

  @spec run_robot([integer]) :: :ok
  defp run_robot(firmware) do
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
end
