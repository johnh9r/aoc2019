defmodule BreakoutArcade do
  @moduledoc """
  model environment for given IntCode[Boost] robot program
  """

  # vvv

  defmodule WorldAffairs do
    @moduledoc """
    maintain state _between_ callbacks from IntCode[Boost] robot process
    """

    # supervisor trees not required in this scenario
    # use Agent

    # next (output) action
    @do_coord_x :coord_x
    @do_coord_y :coord_y
    @do_paint :paint

    # tile_id encoding from problem definition
    @empty  0
    @wall   1
    @block  2
    @paddle 3
    @ball   4

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
      tiles = Keyword.fetch!(kw, :panels)

      raise "input action not supported or required for first part"
    end

    @doc """
    # iex> BreakoutArcade.WorldAffairs.handle_output_request()
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
        @do_coord_x ->
          Agent.update(
            __MODULE__,
            fn state ->
              buffer = Keyword.fetch!(state, :buffer)
              # sanity check
              0 = length(buffer)

              Keyword.merge(
                state,
                [
                  buffer: [value],
                  next_action: @do_coord_y,
                ]
              )
            end
          )

        @do_coord_y ->
          Agent.update(
            __MODULE__,
            fn state ->
              buffer = Keyword.fetch!(state, :buffer)
              # sanity check
              1 = length(buffer)

              Keyword.merge(
                state,
                [
                  buffer: buffer ++ [value],
                  next_action: @do_paint,
                ]
              )
            end
          )

        @do_paint ->
          Agent.update(
            __MODULE__,
            fn state ->
              tiles = Keyword.fetch!(state, :tiles)
              [x, y] = Keyword.fetch!(state, :buffer)

              # overwrite (w/o maintaining history)
              new_tiles = Map.put(tiles, {x, y}, value)
              # IO.inspect({x,y,value}, label: "\n")

              Keyword.merge(
                state,
                [
                  tiles: new_tiles,
                  # reset
                  buffer: [],
                  next_action: @do_coord_x,
                ]
              )
            end
          ) 
      end
      {:ok}
    end

    # auxiliary functions to share select constants with enclosing module
    def coord_x, do: @do_coord_x
    def coord_y, do: @do_coord_y
    def paint, do: @do_paint
    def block, do: @block
  end

  # ^^^

  @doc """
  part 1
  """
  @spec count_block_tiles_on_exit([integer]) :: integer
  def count_block_tiles_on_exit(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        tiles: %{},
        buffer: [],
        next_action: WorldAffairs.coord_x()
      ]
    )

    run_robot(firmware)

    kw = WorldAffairs.get_final_state()

    Keyword.fetch!(kw, :tiles)
    |> Map.to_list()
    |> Enum.filter(fn {{x, y}, tile_id} -> tile_id == WorldAffairs.block() end)
    |> IO.inspect(label: "\n", limit: :infinity)
    |> Kernel.length()
  end

  @spec run_robot([integer]) :: {:ok}
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
    {:ok}
  end
end
