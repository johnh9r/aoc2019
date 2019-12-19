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
  """

  alias TractorBeam.WorldAffairs

  # from problem definition
  @x_max 49
  @y_max 49

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
    {:ok, _pid} = WorldAffairs.initialize([])

    0..@y_max
    |> Enum.reduce(
      MapSet.new(),
      fn y, outer_acc ->
        0..@x_max
        |> Enum.reduce(
          outer_acc,
          fn x, inner_acc ->
            WorldAffairs.set_drone_coordinates(x, y)
            run_single_use_drone(firmware)
            state = WorldAffairs.get_final_state()
            case Keyword.fetch!(state, :affected) do
              1 -> MapSet.put(inner_acc, {x,y})
              _ -> inner_acc
            end
          end
        )
      end
    )
    |> MapSet.size()
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
end
