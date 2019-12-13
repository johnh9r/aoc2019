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
    @do_score_noop :score_noop
    @do_score_value :score_value

    # invalid x-coordinate: escape for updating score w/ following value
    @coord_esc -1

    # tile_id encoding from problem definition
    @empty  0
    @wall   1
    @block  2
    @paddle 3
    @ball   4

    @j_ 0
    @jl -1
    @jr 1

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
      tiles =
        Keyword.fetch!(kw, :tiles)
        |> render_screen()
        |> (fn screen -> ["\n\n" | screen] end).()
        |> IO.write()

      [joy_move | remaining_joy_moves] = Keyword.fetch!(kw, :joy_moves)

      Agent.update(
        __MODULE__,
        fn state -> Keyword.merge(state, [joy_moves: remaining_joy_moves]) end
      )

      joy_move
    end

    @doc """
    # iex> BreakoutArcade.WorldAffairs.handle_output_request()
    """
    # 
    @spec handle_output_request(integer) :: :ok
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

              case value do
                @coord_esc ->
                  Keyword.merge(state, [next_action: @do_score_noop])

                _ ->
                  Keyword.merge(state, [buffer: [value], next_action: @do_coord_y, ]) end
            end
          )

        @do_coord_y ->
          Agent.update(
            __MODULE__,
            fn state ->
              buffer = Keyword.fetch!(state, :buffer)
              # sanity check
              1 = length(buffer)
              Keyword.merge(state, [buffer: buffer ++ [value], next_action: @do_paint]) end)

        @do_paint ->
          Agent.update(
            __MODULE__,
            fn state ->
              tiles = Keyword.fetch!(state, :tiles)
              [x, y] = Keyword.fetch!(state, :buffer)

              # overwrite (w/o maintaining history)
              new_tiles = Map.put(tiles, {x, y}, value)
              # IO.inspect({x,y,value}, label: "\n")

              Keyword.merge(state, [tiles: new_tiles, buffer: [], next_action: @do_coord_x]) end)

        @do_score_noop ->
          Agent.update(
            __MODULE__,
            fn state -> Keyword.merge(state, [next_action: @do_score_value]) end
          )

        @do_score_value ->
          Agent.update(
            __MODULE__,
            fn state -> Keyword.merge(state, [score: value, next_action: @do_coord_x]) end
          )
          IO.inspect(value, label: "\nscore")
      end
      :ok
    end

    @spec render_screen(%{required({integer, integer}) => integer}) :: iodata
    defp render_screen(tiles) do
      tiles
      # use y-coordinate as dominant sort key in order to form scan lines
      |> Enum.group_by(fn {{_x, y}, _tile_id} -> y end)
      |> Enum.into(
        [],
        fn {_group_key_y, tiles} ->
          tiles
          |> Enum.sort_by(fn {{x, y},_} -> x end)
          |> Enum.map(fn {{x,y}, tile_id} -> tile_id end)
        end
      )
      |> Enum.map(
        fn tiles_in_scan_line ->
          tiles_in_scan_line
          |> Enum.reduce(
            [],
            fn tile_id, acc ->
              tile_ch =
                case tile_id do
                  @empty -> " "
                  @wall -> "#"
                  @block -> "*"
                  @paddle -> "^"
                  @ball -> "O"
                  x -> raise "unknown tile_id #{x}"
                end

              [tile_ch | acc]
            end
          )
        end
      )
      |> Enum.map(&Enum.reverse/1)
      |> Enum.intersperse("\n")
    end

    # auxiliary functions to share select constants with enclosing module
    def coord_x, do: @do_coord_x
    def coord_y, do: @do_coord_y
    def paint, do: @do_paint

    def empty, do: @empty
    def wall, do: @wall
    def block, do: @block
    def paddle, do: @paddle
    def ball, do: @ball
  end

  # ^^^

  @doc """
  part 2
  """
  @spec calc_highscore_on_completion([integer]) :: integer
  def calc_highscore_on_completion(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        tiles: %{},
        buffer: [],
        score: 0,
        joy_moves: [:j_, :j_, :j_, :j_, :j_, :j_],
        next_action: WorldAffairs.coord_x()
      ]
    )

    run_robot(firmware)

    kw = WorldAffairs.get_final_state()

    #TODO
  end

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
    |> count_blocks()
  end

  @spec count_blocks([integer]) :: integer
  defp count_blocks(tiles) do
    tiles
    |> Map.to_list()
    |> Enum.filter(fn {{x, y}, tile_id} -> tile_id == WorldAffairs.block() end)
    |> Kernel.length()
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
