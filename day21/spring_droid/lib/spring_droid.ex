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
end


defmodule SpringDroid do
  @moduledoc """
  model environment for given IntCode[Boost] robot program
  """

  alias SpringDroid.WorldAffairs

  @doc """
  part 2

  best brush up on your [Boolean algebra](https://en.wikipedia.org/wiki/Boolean_algebra#Laws)
  """
  @spec calc_hull_damage_running([integer]) :: integer
  def calc_hull_damage_running(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      [
        damage: nil,
        #
        # A' + B'D + C'DE + C'DE'F' + C'DE'H    <!< from notes.txt
        #
        # by distributivity of AND over OR:
        #
        # A' + B'D + C'D(E + E'F' + E'H)
        #
        # evidently max 15 _logic_ instructions (not counting RUN)
        #
        spring_script: """
          NOT E T
          NOT F J
          AND T J
          NOT E T
          AND H T
          OR T J
          OR E J
          NOT C T
          AND D T
          AND T J
          NOT B T
          AND D T
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
