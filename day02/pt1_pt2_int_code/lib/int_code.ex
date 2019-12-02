defmodule IntCode do
  @moduledoc """
  execute RISC-ish instructions on integer data;
  von Neumann architecture exploited for self-modifying code

  ### observations:
  * lazy loading of input stream appears attractive, but requires extra machinery
  * instruction 99 violates 4-octet instruction format
  * absolute addressing
    - earlier data positions can be accessed by opcodes appearing later
    - earlier opcodes can reference data beyond their own position
  * linear execution
    - no jump instruction, so iterate at granularity of instruction format
  * input stream cannot contain holes (for lack of notation), inviting list representation
  * input stream can self-modify by writing to later opcode positions

  ### assumptions:
  * data references will not reach beyond boundaries of input stream(?)
  * instruction stream will terminate properly, not end abruptly(?)
  * input stream will not contain negative values, making it impossible to generate such

  ### constraints:
  * type `Integer` in Elixir is arbitrary-precision so cannot overflow
  """

  @insn_size 4

  @doc """
  iex> IntCode.execute([1, 9, 10, 3, 2, 3, 11, 0, 99, 30, 40, 50])
  [3500, 9, 10, 70, 2, 3, 11, 0, 99, 30, 40, 50]

  iex> IntCode.execute([1, 0, 0, 0, 99])
  [2, 0, 0, 0, 99]

  iex> IntCode.execute([2, 3, 0, 3, 99])
  [2, 3, 0, 6, 99]

  iex> IntCode.execute([2, 4, 4, 5, 99, 0])
  [2, 4, 4, 5, 99, 9801]

  iex> IntCode.execute([1, 1, 1, 4, 99, 5, 6, 0, 99])
  [30, 1, 1, 4, 2, 5, 6, 0, 99]
  """
  @spec execute([integer]) :: [integer]
  def execute([]), do: []

  def execute(xs) do
    _execute(xs, 0)
  end

  @spec _execute([integer], integer) :: [integer]
  defp _execute(xs, i) do
    # best-effort: read may be short (w/o error)
    insn = Enum.slice(xs, i, @insn_size)
    op = List.first(insn)

    case op do
      99 ->
        xs

      1 ->
        [_, ld1off, ld2off, st_off] = insn

        List.replace_at(xs, st_off, Enum.fetch!(xs, ld1off) + Enum.fetch!(xs, ld2off))
        |> _execute(i + @insn_size)

      2 ->
        [_, ld1off, ld2off, st_off] = insn

        List.replace_at(xs, st_off, Enum.fetch!(xs, ld1off) * Enum.fetch!(xs, ld2off))
        |> _execute(i + @insn_size)

      _ ->
        []
    end
  end
end
