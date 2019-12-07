defmodule Amps do
  @moduledoc """
  determine maximum achievable thrust from exhaustive settings permutations across five amplifiers

  ##  observations
  * subtle hint of concurrency (pt1): "(If the amplifier has not yet received an input signal, it waits until one arrives.)"
  """

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
    |> Enum.map(fn phases -> run_processes_pt1(firmware, phases) end)
    |> Enum.max_by(fn {thrust, _phases} -> thrust end)
  end

  defp run_processes_pt1(firmware, [phase_a, phase_b, phase_c, phase_d, phase_e] = phases) do
    # by problem definition, first input is zero
    {line_out_a, _} = IntCodeDoublePlus.execute(firmware, [phase_a, 0])
    {line_out_b, _} = IntCodeDoublePlus.execute(firmware, [phase_b, line_out_a])
    {line_out_c, _} = IntCodeDoublePlus.execute(firmware, [phase_c, line_out_b])
    {line_out_d, _} = IntCodeDoublePlus.execute(firmware, [phase_d, line_out_c])
    {line_out_e, _} = IntCodeDoublePlus.execute(firmware, [phase_e, line_out_d])
    {
      line_out_e,
      phases |> Enum.map_join("", &Integer.to_string/1)
    }
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
