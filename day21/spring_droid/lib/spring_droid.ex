defmodule SpringDroid.WorldAffairs do
  @moduledoc """
  maintain state between callbacks from IntCode[Boost] springdroid process
  """

  # supervisor trees not required in this scenario
  # use Agent

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
    kw = Agent.get(__MODULE__, fn state -> state end)
    [c | remaining_script] = Keyword.fetch!(kw, :spring_script)
    Agent.update(__MODULE__, fn state -> Keyword.merge(state, [spring_script: remaining_script]) end)
    <<i::8, 0::8>> = c <> <<0::8>>
    i
  end

  @spec handle_output_request(integer) :: :ok
  def handle_output_request(value) do
    case value > 127 do
      true ->
        Agent.update(__MODULE__, fn state -> Keyword.merge(state, [damage: value]) end)
      _ ->
        # raise ArgumentError, message: "TODO: handle #{value} etc."
        IO.write(<<value::8>>)
        IO.write(" ")
    end
  end

  # @spec render_screen(%{required({integer, integer}) => integer}) :: iodata
  # defp render_screen(tiles) do
  #   tiles
  #   # use y-coordinate as dominant sort key in order to form scan lines
  #   |> Enum.group_by(fn {{_x, y}, _tile_id} -> y end)
  #   |> Enum.into(
  #     [],
  #     fn {_group_key_y, tiles} ->
  #       tiles
  #       |> Enum.sort_by(fn {{x, _y},_} -> x end)
  #       |> Enum.map(fn {{_x,_y}, tile_id} -> tile_id end)
  #     end
  #   )
  #   |> Enum.map(
  #     fn tiles_in_scan_line ->
  #       tiles_in_scan_line
  #       |> Enum.reduce(
  #         [],
  #         fn tile_id, acc ->
  #           tile_ch =
  #             case tile_id do
  #               @empty -> " "
  #               @wall -> "#"
  #               @block -> "*"
  #               @paddle -> "^"
  #               @ball -> "O"
  #               x -> raise "unknown tile_id #{x}"
  #             end
  #           [tile_ch | acc]
  #         end
  #       )
  #     end
  #   )
  #   |> Enum.map(&Enum.reverse/1)
  #   |> Enum.intersperse("\n")
  # end
end


defmodule SpringDroid do
  @moduledoc """
  model environment for given IntCode[Boost] robot program
  """

  alias SpringDroid.WorldAffairs

  @doc """
  part 2

  not(A) is trivial and further six sensors can be [solved by Quine-McCluskey](http://32x8.com/sop6_____A-B-C-D-E-F_____m_8-9-10-11-12-13-14-15-24-25-26-27-40-41-42-44-45-46-47_____d_32-33-48_____option-0_____899788975371824592809), taking care to rename variables
  """
  @spec calc_hull_damage_running([integer]) :: integer
  def calc_hull_damage_running(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        damage: nil,
        #
        #        v       v       v       v
        # A' + B'DE' + C'DF' + C'DG' + C'DE
        #              ~~~     ~~~     ~~~
        # by distributivity of AND over OR(+):
        #
        # A' + B'DE' + C'D(F' + G' + E)
        #
        # by DeMorgan's Law:
        #
        # A' + (BD'E)' + C'D(F' + G' + E)
        #
        spring_script: """
          NOT F T
          NOT G J
          OR T J
          OR E J
          NOT C T
          AND D T
          AND T J
          NOT D T
          OR B T
          OR E T
          NOT T T
          OR T J
          NOT A T
          OR T J
          RUN
          """
          |> String.split(~r//, trim: true)
      ]
    )

    IO.write("\n")
    run_spring_droid(firmware)

    kw = WorldAffairs.get_final_state()
         |> IO.inspect(label: "\nresult")

    Keyword.fetch!(kw, :damage)
  end

  @doc """
  part 1

  ## notes
  * https://en.wikipedia.org/wiki/Karnaugh_map
  """
  @spec calc_hull_damage_walking([integer]) :: integer
  def calc_hull_damage_walking(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        damage: nil,
        # !a || (!b && d) || (!c && d)
        # really: ["N", "O", "T", " ", "B", " ", "T", "\n", "A", "N", "D", etc.]
        spring_script: """
          NOT B T
          AND D T
          NOT C J
          AND D J
          OR J T
          NOT A J
          OR T J
          WALK
          """
          |> String.split(~r//, trim: true)
      ]
    )

    IO.write("\n")
    run_spring_droid(firmware)

    kw = WorldAffairs.get_final_state()
         |> IO.inspect(label: "\nresult")

    Keyword.fetch!(kw, :damage)
  end

  @spec run_spring_droid([integer]) :: :ok
  defp run_spring_droid(firmware) do
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
