defmodule IntCodeBoost do
  use Task

  @no_opts []

  @moduledoc """
  execute CISC instructions on integer data

  * support relative addressing
  * support arbitrary-precision integers
  * support initialised memory beyond loaded image
  """

  # addressing modes for opcode parameters
  @pos_mode 0
  @imm_mode 1
  @rel_mode 2

  @spec execute_with_inputs([integer], [integer]) :: [integer]
  def execute_with_inputs(firmware, inputs) do
    # both (in/out) from perspective of IntCodeBoost machine
    input_fun = fn -> receive do {value} -> value end end
    output_fun = fn value -> Process.send(self(), {value}, @no_opts) end

    task = Task.async(fn -> execute(firmware, input_fun, output_fun) end)

    inputs
    |> Enum.map(fn value -> Process.send(task.pid, {value}, @no_opts) end)

    Task.await(task)

    receive do
      {result} -> result
    end
  end

  @doc """
  iex> IntCodeBoost.execute([1, 9, 10, 3, 2, 3, 11, 0, 99, 30, 40, 50])
  [3500, 9, 10, 70, 2, 3, 11, 0, 99, 30, 40, 50]

  iex> IntCodeBoost.execute([1, 0, 0, 0, 99])
  [2, 0, 0, 0, 99]

  iex> IntCodeBoost.execute([2, 3, 0, 3, 99])
  [2, 3, 0, 6, 99]

  iex> IntCodeBoost.execute([2, 4, 4, 5, 99, 0])
  [2, 4, 4, 5, 99, 9801]

  iex> IntCodeBoost.execute([1, 1, 1, 4, 99, 5, 6, 0, 99])
  [30, 1, 1, 4, 2, 5, 6, 0, 99]

  # OK -- quine: outputs itself (using opcode 4), but expands memory
  # iex> IntCodeBoost.execute([109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99])
  # [109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99]

  iex> IntCodeBoost.execute([1102,34915192,34915192,7,4,7,99,0])
  [1102,34915192,34915192,7,4,7,99,1219070632396864]

  # ... -- output only
  iex> IntCodeBoost.execute([104,1125899906842624,99])
  [104,1125899906842624,99]
  """
  @spec execute([integer], (-> integer), (integer -> integer)) :: [integer]
  def execute(
    xs,
    input_fun \\ fn -> raise "(EOF@stdin)" end,
    output_fun \\ fn _ -> false end
  )
  def execute([], _, _), do: []
  def execute(xs, input_fun, output_fun), do: _execute(xs, 0, 0, input_fun, output_fun)

  # parameters: firmware, instruction offset, relative base, input, output
  @spec _execute([integer], integer, integer, (-> integer), (integer -> integer)) :: [integer]
  defp _execute(xs, i, rel_base, input_fun, output_fun) do
    [op_param_modes] = cisc_at(xs, i, 1)

    op = op_param_modes |> Kernel.rem(100)
    param_mode1 = op_param_modes |> Kernel.div(  100) |> Kernel.rem(10)
    param_mode2 = op_param_modes |> Kernel.div( 1000) |> Kernel.rem(10)
    #    Day _: "Parameters that an instruction writes to will never be in immediate mode."
    # vs Day 9: "Like position mode, parameters in relative mode can be read from or written to."
    param_mode3 = op_param_modes |> Kernel.div(10000) |> Kernel.rem(10)

    case op do
      # halt (returning core dump for possible debugging)
      99 ->
        xs

      # add
      1 ->
        insn_sz = 4
        [_, ld1off, ld2off, st_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)
        {xs, value1} = load_param1.(xs, ld1off)
        {xs, value2} = load_param2.(xs, ld2off)

        store_param3 = writer_for(param_mode3, rel_base)
        {xs} = store_param3.(xs, st_off, value1 + value2)

        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # mult
      2 ->
        insn_sz = 4
        [_, ld1off, ld2off, st_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)
        {xs, value1} = load_param1.(xs, ld1off)
        {xs, value2} = load_param2.(xs, ld2off)

        store_param3 = writer_for(param_mode3, rel_base)
        {xs} = store_param3.(xs, st_off, value1 * value2)

        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # store input from environment
      3 ->
        insn_sz = 2
        [_, st_off] = cisc_at(xs, i, insn_sz)
        
        store_param1 = writer_for(param_mode1, rel_base)
        value = input_fun.()
        {xs} = store_param1.(xs, st_off, value)

        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # generate output to environment
      4 ->
        insn_sz = 2
        [_, ld_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        {xs, output_value} = load_param1.(xs, ld_off)

        IO.inspect(output_value, label: "\noutput")

        output_fun.(output_value)
        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # jmpnz
      5 ->
        insn_sz = 3
        [_, ld_off, target] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)
        {xs, value} = load_param1.(xs, ld_off)
        {xs, target} = load_param2.(xs, target)

        if value != 0 do
          _execute(xs, target, rel_base, input_fun, output_fun)
        else
          _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)
        end

      # jmpz
      6 ->
        insn_sz = 3
        [_, ld_off, target] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)
        {xs, value} = load_param1.(xs, ld_off)
        {xs, target} = load_param2.(xs, target)

        if value == 0 do
          _execute(xs, target, rel_base, input_fun, output_fun)
        else
          _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)
        end

      # stlt
      7 ->
        insn_sz = 4
        [_, ld1off, ld2off, st_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)

        {xs, value1} = load_param1.(xs, ld1off)
        {xs, value2} = load_param2.(xs, ld2off)

        store_param3 = writer_for(param_mode3, rel_base)

        value =
          if value1 < value2,
            do: 1,
            else: 0

        {xs} = store_param3.(xs, st_off, value)
        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # steq
      8 ->
        insn_sz = 4
        [_, ld1off, ld2off, st_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        load_param2 = loader_for(param_mode2, rel_base)

        {xs, value1} = load_param1.(xs, ld1off)
        {xs, value2} = load_param2.(xs, ld2off)

        store_param3 = writer_for(param_mode3, rel_base)

        value =
          if value1 == value2,
            do: 1,
            else: 0

        {xs} = store_param3.(xs, st_off, value)
        _execute(xs, i + insn_sz, rel_base, input_fun, output_fun)

      # rboff
      9 ->
        insn_sz = 2
        [_, rel_off] = cisc_at(xs, i, insn_sz)

        load_param1 = loader_for(param_mode1, rel_base)
        {xs, rel_base_offset} = load_param1.(xs, rel_off)

        _execute(xs, i + insn_sz, rel_base + rel_base_offset, input_fun, output_fun)

      x ->
        raise "unknown opcode: #{Integer.to_string(x)}"
    end
  end

  defp loader_for(param_mode, rel_base) do
    # all mode handlers must uniformly support dynamic memory growth
    case param_mode do
      @pos_mode ->
        &load_at!/2

      @imm_mode ->
        fn xs, x -> {xs, x} end

      @rel_mode ->
        fn xs, offset -> load_at!(xs, rel_base + offset) end

      x ->
        raise "unknown param mode: #{x}"
    end
  end

  defp writer_for(param_mode, rel_base) do
    # all mode handlers must uniformly support dynamic memory growth
    case param_mode do
      @pos_mode ->
        &store_at/3

      @imm_mode ->
        # Day _: "Parameters that an instruction writes to will never be in immediate mode."
        raise "unsupported immediate mode parameter for write access"

      @rel_mode ->
        fn xs, offset, value -> store_at(xs, rel_base + offset, value) end

      x ->
        raise "unknown param mode: #{x}"
    end
  end

  # memory (data) access may dynamically (and magically) grow available memory
  # assumption:  no jumps into freshly initialised memory, since opcode 0 invalid

  @spec load_at!([integer], integer) :: {[integer], integer}
  defp load_at!(xs, offset) do
    implied_xs = ensure_sufficent_memory(xs, offset)
    value = Enum.fetch!(implied_xs, offset)
    {implied_xs, value}
  end

  @spec store_at([integer], integer, integer) :: {[integer]}
  defp store_at(xs, offset, value) do
    implied_xs = ensure_sufficent_memory(xs, offset)
    updated_xs = List.replace_at(implied_xs, offset, value)
    {updated_xs}
  end

  # first instruction resides at position zero;
  # return empty list on out-of-bounds access attempt
  @spec cisc_at([integer], integer, integer) :: [integer]
  defp cisc_at(xs, i, n) do
    xs
    |> Enum.drop(i)
    |> Enum.take(n)
  end

  @spec ensure_sufficent_memory([integer], integer) :: [integer]
  def ensure_sufficent_memory(xs, offset) do
    if length(xs) <= offset do
      initialised_padding = Stream.cycle([0]) |> Enum.take(offset - length(xs) + 1)
      xs ++ initialised_padding
    else
      xs
    end
  end
end
