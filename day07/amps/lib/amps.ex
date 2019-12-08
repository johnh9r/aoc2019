defmodule Amps do
  use Task

  @moduledoc """
  determine maximum achievable thrust from exhaustive settings permutations across five amplifiers

  ##  observations
  * subtle hint of concurrency (pt1): "(If the amplifier has not yet received an input signal, it waits until one arrives.)"
  """

  # Process.send(pid, msg, opts)
  @no_opts []

  @doc """
  iex> Amps.max_feedback_thrust([3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5], [5,6,7,8,9])
  {139_629_729, "98765"}

  iex> Amps.max_feedback_thrust([3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55,1005,55,26,1001,54,-5,54,1105,1,12,1,53,54,53,1008,54,0,55,1001,55,1,55,2,53,55,53,4,53,1001,56,-1,56,1005,56,6,99,0,0,0,0,10], [5,6,7,8,9])
  {18216, "97856"}
  """
  @spec max_feedback_thrust([integer], [integer]) :: tuple
  def max_feedback_thrust(firmware, settings) do
    permutations(settings)
    |> Enum.map(
      fn phases ->
        run_concurrent_processes(firmware, phases)
      end
    )
    |> Enum.max_by(fn {thrust, _phases} -> thrust end)
  end

  @doc """
  iex> Amps.max_thrust([3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0], [0,1,2,3,4])
  {43210, "43210"}

  iex> Amps.max_thrust([3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0], [0,1,2,3,4])
  {54321, "01234"}

  iex> Amps.max_thrust([3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33,1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0], [0,1,2,3,4])
  {65210, "10432"}
  """
  @spec max_thrust([integer], [integer]) :: tuple
  def max_thrust(firmware, settings) do
    permutations(settings)
    |> Enum.map(
      fn phases ->
        run_sequential_processes(firmware, phases)
      end
    )
    |> Enum.max_by(fn {thrust, _phases} -> thrust end)
  end

  # rough and ready process management: best effort or crash in flames
  #
  # %Task{
  #   owner: #PID<0.150.0>,
  #   pid: #PID<0.151.0>,
  #   ref: #Reference<0.3545205543.2033713154.216017>
  # }
  defp run_sequential_processes(firmware, phases) do
    result_collector_task =
      Task.async(fn -> receive do {value} -> value end end)

    # process mailbox acting like list parameter, e.g. [phase_a, ...]
    tasks_with_phase_init =
      phases
      |> Enum.reverse()
      # build process list backwards, so each stage know its successor
      |> Enum.reduce(
        [result_collector_task],
        fn phase, [successor_task | _] = acc ->
          task = Task.async(
            IntCodeDoublePlus,
            :execute,
            [
              firmware,
              # both (in/out) from perspective of IntCode machine
              fn -> receive do {value} -> value end end,
              fn value -> Process.send(successor_task.pid, {value}, @no_opts) end
            ]
          )
          Process.send(task.pid, {phase}, @no_opts)
          [task | acc]
        end
      )

    # by problem definition, first input is zero
    first_task =
      tasks_with_phase_init
      |> List.first()

    Process.send(first_task.pid, {0}, @no_opts)

    {
      Task.await(result_collector_task),
      phases |> Enum.map_join("", &Integer.to_string/1)
    }
  end

  defp run_concurrent_processes(firmware, phases) do
    result_collector_task = Task.async(fn -> collect_result(nil) end)

    # process mailbox acting like list parameter, e.g. [phase_a, ...]
    tasks_with_phase_init =
      phases
      |> Enum.reverse()
      # build process list backwards, so each stage knows its successor
      |> Enum.reduce(
        [result_collector_task],
        fn phase, [successor_task | _] = acc ->
          task =
            Task.async(
              IntCodeDoublePlus,
              :execute,
              [
                firmware,
                # both (in/out) from perspective of IntCode machine
                fn -> receive do {value} -> value end end,
                fn value -> Process.send(successor_task.pid, {value}, @no_opts) end
              ]
            )
          Process.send(task.pid, {phase}, @no_opts)
          [task | acc]
        end
      )

    [first_task | _] = tasks_with_phase_init

    # establish feedback loop after all tasks launched (but still blocking on input)
    Process.send(result_collector_task.pid, {:pid, first_task.pid}, @no_opts)

    # by problem definition, first input is zero
    Process.send(first_task.pid, {0}, @no_opts)

    {
      Task.await(result_collector_task),
      phases |> Enum.map_join("", &Integer.to_string/1)
    }
  end

  defp collect_result(loop_pid) do
    receive do
      # tail-recursive call to remember PID and iterate over feedback loop passes
      {:pid, first_task_pid} ->
        first_task_pid
        |> collect_result()
      {value} ->
        if Process.alive?(loop_pid) do
          # feedback loop
          Process.send(loop_pid, {value}, @no_opts)
          collect_result(loop_pid)
        else
          value
        end
    end
  end

  @doc """
  iex> Amps.permutations([])
  [[]]

  iex> Amps.permutations([1])
  [[1]]

  iex> Amps.permutations([1, 2])
  [[1, 2], [2, 1]]

  iex> Amps.permutations([1, 2, 3])
  [
    [1, 2, 3],
    [1, 3, 2],
    [2, 1, 3],
    [2, 3, 1],
    [3, 1, 2],
    [3, 2, 1]
  ]

  ##  polyglot alternative: copy-and-paste Python output
  import itertools
  import pprint
  pp = pprint.PrettyPrinter(indent=2)
  pp.pprint(map(lambda t: map(lambda s: int(s), t), itertools.permutations('01234')))
  """
  @spec permutations([integer]) :: [[integer]]
  def permutations([]), do: [[]]
  def permutations([value]), do: [[value]]
  def permutations(values) do
    Range.new(1, length(values))
    |> Enum.flat_map(
      fn i ->
        {this, others} = List.pop_at(values, i - 1)
        Enum.map(permutations(others), fn os -> [this | os] end)
      end
    )
  end
end
