defmodule RoboPaintWorld do
  @moduledoc """
  model environment for given IntCode[Boost] robot program

  ##  assumptions
  * program will at least paint start location (cf initialisation data)
  """

  # vvv

  defmodule WorldAffairs do
    @moduledoc """
    maintain state _between_ callbacks from IntCode[Boost] robot process

    IDEA: %{ {x, y} => [..., {:wht, 4}, {:blk, -1}] }
    IDEA: Keyword list  [panels: %{see above}, location: {2,1}, direction: :north,  next_action: :paint, movement_counter: 5]

    ## notes from problem definition
    1. (input to robot)    detect colour of panel in current location (0|1)
    2. (output from robot) paint colour of panel in current location (0|1)
    3a.(output from robot) turn 90deg in given direction (0=L|1=R)
    3b.(implicitly)        change location by moving forward one step
    """

    # supervisor trees not required in this scenario
    # use Agent

    # next robot action (to help interpret its plain numeric output values)
    @do_paint :paint
    @do_move :turn_and_move

    # colour encoding from problem definition
    @blk 0
    @wht 1

    # movements from problem definition
    @turn_left_and_advance 0
    @turn_right_and_advance 1

    # direction of robot (changed from problem definition)
    @north :north
    @east  :east
    @south :south
    @west  :west

    # implicitly coloured panels were painted prior to robot starting (with movement_count == 0)
    @by_default -1

    @doc """
    """
    @spec initialize(Keyword.t()) :: pid
    def initialize(initial_state) do
      Agent.start_link(fn -> initial_state end, name: __MODULE__)
    end

    @doc """
    """
    @spec get_final_state() :: Keyword.t()
    def get_final_state() do
      Agent.get(__MODULE__, fn state -> state end)
    end

    @doc """
    # iex> RoboPaintWorld.WorldAffairs.handle_input_request()
    """
    @spec handle_input_request() :: {integer}
    def handle_input_request() do
      # restore context to answer question
      kw = Agent.get(__MODULE__, fn state -> state end)
      panels = Keyword.fetch!(kw, :panels)
      location = Keyword.fetch!(kw, :location)

      # newly reached panels initialised during movement (or at start-up)
      [{colour, _step} | _] = panels[location]
      colour
      |> IO.inspect(label: "\ninp")
    end

    @doc """
    # iex> RoboPaintWorld.WorldAffairs.handle_output_request()
    """
    # 
    @spec handle_output_request(integer) :: {:ok}
    def handle_output_request(value) do
      # restore context to change world
      kw = Agent.get(__MODULE__, fn state -> state end)
      action = Keyword.fetch!(kw, :next_action)

      # in this scenario (single client), no safety or performance concerns
      # over executing functions on agent
      case action do
        @do_paint ->
          Agent.update(
            __MODULE__,
            fn state ->
              panels = Keyword.fetch!(state, :panels)
              location = Keyword.fetch!(state, :location)
              movement_counter = Keyword.fetch!(state, :movement_counter)

              # XXX closure over value?!
              {_, new_panels} =
                Map.get_and_update!(
                  panels,
                  location,
                  fn history ->
                    {history, [{value, movement_counter} | history]}
                  end
                )

              Keyword.merge(
                state, [
                  panels: new_panels,
                  # location: ...
                  # direction: ...
                  next_action: @do_move,
                  # movement_counter: ...
                ]
                # |> IO.inspect(label: "\npainted")
              )
            end
          ) 

        @do_move ->
          Agent.update(
            __MODULE__,
            fn state ->
              panels = Keyword.fetch!(state, :panels)
              location = Keyword.fetch!(state, :location)
              direction = Keyword.fetch!(state, :direction)
              movement_counter = Keyword.fetch!(state, :movement_counter)

              # XXX closure over value?!
              {new_location, new_direction} = next_location_and_direction(location, direction, value)

              # default square to black iff newly discovered
              new_panels = Map.put_new(panels, new_location, [{@blk, @by_default}])
              Keyword.merge(
                state, [
                  panels: new_panels,
                  location: new_location,
                  direction: new_direction,
                  next_action: @do_paint,
                  movement_counter: movement_counter + 1
                ]
                # |> IO.inspect(label: "\nmoved")
              )
            end
          ) 
      end
      {:ok}
    end

    @doc """
        N [+]
        | 
      W-o-E  
        | 
    [-] S
    """
    @spec next_location_and_direction({integer, integer}, integer, integer) :: {{integer, integer}, integer}
    def next_location_and_direction({x, y} = _location, direction, turn_insn) do
      {{dx,dy}, new_direction} =
        case direction do
          @north ->
            case turn_insn do
              @turn_left_and_advance -> {{-1,0}, @west}
              @turn_right_and_advance -> {{1,0}, @east}
            end

          @east ->
            case turn_insn do
              @turn_left_and_advance -> {{0,1}, @north}
              @turn_right_and_advance -> {{0,-1}, @south}
            end

          @south ->
            case turn_insn do
              @turn_left_and_advance -> {{1,0}, @east}
              @turn_right_and_advance -> {{-1,0}, @west}
            end

          @west ->
            case turn_insn do
              @turn_left_and_advance -> {{0,-1}, @south}
              @turn_right_and_advance -> {{0,1}, @north}
            end
        end

      {{x + dx, y + dy}, new_direction}
      # |> IO.inspect(label: "\nloc_dir")
    end

    # auxiliary functions to share select constants with enclosing module
    def black, do: @blk
    def white, do: @wht
    def by_default, do: @by_default
    def north, do: @north
    def paint, do: @do_paint
  end

  # ^^^

  @doc """
  # iex> RoboPaintWorld.paint_registration_markings()
  """
  @spec paint_registration_markings([integer]) :: {:ok}
  def paint_registration_markings(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        panels: %{{0, 0} => [{WorldAffairs.white(), WorldAffairs.by_default()}]},
        location: {0, 0},
        direction: WorldAffairs.north(),
        # robot has not yet moved, but may paint immediately
        next_action: WorldAffairs.paint(),
        movement_counter: 0
      ]
      # |> IO.inspect(label: "\ninit")
    )

    run_robot(firmware)

    kw = WorldAffairs.get_final_state()

    Keyword.fetch!(kw, :panels)
    |> Enum.sort(fn {{u, v}, _}, {{x, y}, _} -> 100 * (100 - v) + u <= 100 * (100 - y) + x end)
    |> Enum.into([], fn {{x,y}, [{colour, _} | _]} -> {{100 + x, 100 + y}, colour} end)
    |> IO.inspect(label: "\nsorted", limit: :infinity)
    |> Enum.reduce(
      {[], {-1,-1}},
      fn {{x,y}, colour}, {all_pixels, {prev_x, _prev_y}} ->
        pixel = if colour == WorldAffairs.black(), do: " ", else: "#"
        maybe_scan_line_terminator = if prev_x + 1 == x, do: "", else: "\n"
        {[pixel | [maybe_scan_line_terminator | all_pixels]], {x, y}}
      end
    )
    |> Tuple.to_list()
    |> List.first()
    |> Enum.join()
    |> IO.inspect(label: "/bin/echo -e ", limit: :infinity)
  end

  @doc """
  # iex> RoboPaintWorld.count_panels_painted()
  """
  @spec count_panels_painted([integer]) :: integer
  def count_panels_painted(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        panels: %{{0, 0} => [{WorldAffairs.black(), WorldAffairs.by_default()}]},
        location: {0, 0},
        direction: WorldAffairs.north(),
        # robot has not yet moved, but may paint immediately
        next_action: WorldAffairs.paint(),
        movement_counter: 0
      ]
      # |> IO.inspect(label: "\ninit")
    )

    run_robot(firmware)

    kw = WorldAffairs.get_final_state()
    
    # ignore panels that were only coloured by default (which must be its most recent history)
    Keyword.fetch!(kw, :panels)
    |> Map.to_list()
    |> Enum.reject(
      fn {{_x, _y}, [{colour, age} | _]} = square ->
        {colour, age} == {WorldAffairs.black(), WorldAffairs.by_default()}
      end
    )
    |> Kernel.length()
  end

  @doc """
  # iex> RoboPaintWorld.run_robot()
  """
  @spec run_robot([integer]) :: {:ok}
  def run_robot(firmware) do
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
    {:ok}
  end
end
