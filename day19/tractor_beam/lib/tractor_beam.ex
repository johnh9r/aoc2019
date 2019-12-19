defmodule TractorBeam.WorldAffairs do
  @moduledoc """
  """

  # from problem definition
  @x_max 49
  @y_max 49

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
    state = Agent.get(__MODULE__, fn state -> state end)
    scan_complete = Keyword.fetch!(state, :scan_complete)
    next = Keyword.fetch!(state, :next)
    x = Keyword.fetch!(state, :x)
    y = Keyword.fetch!(state, :y)

    case {scan_complete, next} do
      {true, _} ->
        # "Negative numbers are invalid and will confuse the drone; all numbers should be zero or positive."
        -1
      {_, :x_axis} ->
        Agent.update(__MODULE__, fn state -> Keyword.merge(state, [next: :y_axis]) end)
        x
      {_, :y_axis} ->
        Agent.update(__MODULE__, fn state -> Keyword.merge(state, [next: :y_axis]) end)
        y
    end
  end

  @spec handle_output_request(integer) :: :ok
  def handle_output_request(value) do
    Agent.update(
      __MODULE__,
      fn state ->
        tiles = Keyword.fetch!(state, :tiles)
        x = Keyword.fetch!(state, :x)
        y = Keyword.fetch!(state, :y)

        new_tiles =
          case value do
            1 -> MapSet.put(tiles, {x,y})
            _ -> tiles
          end

        {x_next, y_next} =
          case x < @x_max do
            true -> {x + 1, y}
            _ -> {0, y + 1}
          end

        changed_state =
          case y_next < @y_max do
            true -> [tiles: new_tiles, x: x_next, y: y_next]
            _ -> [tiles: new_tiles, x: x_next, y: y_next, scan_complete: true] 
          end

        Keyword.merge(state, changed_state)
      end
    )
  end
end


defmodule TractorBeam do
  @moduledoc """
  ## notes
  * coordinate system with {0,0} = top/left and both x and y growing into positive range
  """

  alias TractorBeam.WorldAffairs

  @doc """
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
    {:ok, _pid} = WorldAffairs.initialize(
      tiles: MapSet.new(),
      next: :x_axis,
      x: 0,
      y: 0,
      scan_complete: false
    )

    run_drone(firmware)

    state = WorldAffairs.get_final_state()
    Keyword.fetch!(state, :tiles)
    |> Kernel.map_size()
  end

  @spec run_drone([integer]) :: :ok
  defp run_drone(firmware) do
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
