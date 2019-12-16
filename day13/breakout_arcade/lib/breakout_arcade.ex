defmodule BreakoutArcade.WorldAffairs do
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

  @joy_neutral 0
  @joy_left -1
  @joy_right 1

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

    {joy_move, remaining_joy_moves} =
      case Keyword.fetch!(kw, :joy_moves) do
        [] -> {@joy_neutral, []}
        [joy_head | joy_tail] -> {joy_head, joy_tail}
      end

    Agent.update(
      __MODULE__,
      fn state -> Keyword.merge(state, [joy_moves: remaining_joy_moves]) end
    )

    joy_move
    |> IO.inspect(label: "\njoyin")
  end

  @def """
  """
  @spec operate_joystick({}, {}) :: integer
  def operate_joystick({_x_ball, y_ball}, {_x_ball_prev, y_ball_prev}) when y_ball <= y_ball_prev do
    # ball moving away from paddle:  no-op, just wait for direction of rebound
    @joy_neutral
  end

  def operate_joystick(state, {x_ball, y_ball}, {x_ball_prev, y_ball_prev}) do
    # TODO record paddle position explicitly in game state
    # ball travelling back towards paddle
    [{{x_paddle, y_paddle}, _}] =
      Keyword.fetch!(state, :tiles)
      |> Enum.filter(fn {_k, v} -> v == @paddle end)

    IO.inspect({x_ball_prev, y_ball_prev}, label: "\ndbg(prev)")
    IO.inspect({x_ball, y_ball}, label: "\ndbg(curr)")
    IO.inspect({x_paddle, y_paddle}, label: "\ndbg(paddle)")

    # calc interception point with paddle scanline
    # always: y_ball < y_paddle (or else it is too late)
    x_target =
      x_ball + (x_ball - x_ball_prev) * (y_paddle - y_ball)

    # calc horiz diff and move joystick accordingly (if at all)
    next_joy_move =
      case x_target - x_paddle do
        n when n == 0 -> @joy_neutral
        n when n < 0 -> @joy_left  # Stream.cycle([@joy_left]) |> Enum.take(abs(n))
        n when n > 0 -> @joy_right  # Stream.cycle([@joy_right]) |> Enum.take(n)
      end
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
                Keyword.merge(state, [buffer: [value], next_action: @do_coord_y, ])
            end
          end
        )

      @do_coord_y ->
        Agent.update(
          __MODULE__,
          fn state ->
            buffer = Keyword.fetch!(state, :buffer)
            # sanity check
            1 = length(buffer)
            Keyword.merge(state, [buffer: buffer ++ [value], next_action: @do_paint])
          end
        )

      @do_paint ->
        Agent.update(
          __MODULE__,
          fn state ->
            tiles = Keyword.fetch!(state, :tiles)
            [x, y] = Keyword.fetch!(state, :buffer)
            playing = Keyword.fetch!(state, :score) > 0

            # overwrite (w/o maintaining history)
            new_tiles = Map.put(tiles, {x, y}, value)

            new_tiles
            |> render_screen()
            |> (fn screen -> if playing, do: ["\n\n" | screen], else: [""] end).()
            |> IO.write()

            case value do
              @ball ->
                # also inject joystick movement (only starting on first rebound from smashed brick)
                ball_prev = Keyword.fetch!(state, :ball_curr)
                next_joy = if playing, do: operate_joystick(state, {x,y}, ball_prev), else: @joy_neutral
                Keyword.merge(
                  state, [
                    tiles: new_tiles,
                    ball_curr: {x,y},
                    ball_prev: ball_prev,
                    buffer: [],
                    joy_moves: [next_joy],
                    next_action: @do_coord_x
                  ]
                )

              _ ->
                Keyword.merge(state, [tiles: new_tiles, buffer: [], next_action: @do_coord_x])
            end
          end
        )

      @do_score_noop ->
        Agent.update(
          __MODULE__,
          fn state -> Keyword.merge(state, [next_action: @do_score_value]) end
        )

      @do_score_value ->
        IO.inspect(value, label: "\nscore")
        Agent.update(
          __MODULE__,
          fn state ->
            Keyword.merge(state, [score: value, next_action: @do_coord_x])
          end
        )
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
        |> Enum.sort_by(fn {{x, _y},_} -> x end)
        |> Enum.map(fn {{_x,_y}, tile_id} -> tile_id end)
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

  def j_, do: @joy_neutral
  def jl, do: @joy_left
  def jr, do: @joy_right
end


defmodule BreakoutArcade do
  @moduledoc """
  model environment for given IntCode[Boost] robot program
  """

  alias BreakoutArcade.WorldAffairs
  # import BreakoutArcade.WorldAffairs, only: [jl: 0, j_: 0, jr: 0]

  @doc """
  part 2
  """
  @spec calc_highscore_on_completion([integer]) :: integer
  def calc_highscore_on_completion(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        tiles: %{},
        ball_curr: {-1, -1},
        ball_prev: {-1, -1},
        buffer: [],
        score: 0,
        # dynamically populated by AutoPlayer _after_ initial scoring event;
        # initial state has ball heading straight towards paddle, so just hold still
        joy_moves: [],  #[j_, j_, j_, j_, j_, j_],
        next_action: WorldAffairs.coord_x()
      ]
    )

    run_robot(firmware)

    kw = WorldAffairs.get_final_state()

    Keyword.fetch!(kw, :score)
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
    |> Enum.filter(fn {{_x, _y}, tile_id} -> tile_id == WorldAffairs.block() end)
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
