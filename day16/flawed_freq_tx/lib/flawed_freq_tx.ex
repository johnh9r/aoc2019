defmodule FlawedFreqTx do
  @moduledoc """
  apply Flawed Frequency Processsing to input message for given number of iterations
  """

  @base_pattern [0, 1, 0, -1]
  # ASCII
  @minus 0x2d

  @doc """
  iex> FlawedFreqTx.run_extra_long_flawed_frequency_processing("03036732577212944063491565474664", 100)
  "84462026"

  iex> FlawedFreqTx.run_extra_long_flawed_frequency_processing("02935109699940807407585447034323", 100)
  "78725270"

  iex> FlawedFreqTx.run_extra_long_flawed_frequency_processing("03081770884921959731165446850517", 100)
  "53553731"
  """
  @spec run_extra_long_flawed_frequency_processing(String.t(), integer) :: String.t()
  def run_extra_long_flawed_frequency_processing(message, iterations) do
    offset =
      message
      |> String.slice(0,7)
      |> String.to_integer()

    [message]
    |> Stream.cycle()
    |> Stream.take(10_000)
    |> Enum.join("")
    |> run_flawed_frequency_processing(iterations, offset)
  end

  @doc """
  iex> FlawedFreqTx.run_flawed_frequency_processing("12345678", 4)
  "01029498"

  iex> FlawedFreqTx.run_flawed_frequency_processing("80871224585914546619083218645595", 100)
  "24176176"

  iex> FlawedFreqTx.run_flawed_frequency_processing("19617804207202209144916044189917", 100)
  "73745418"

  iex> FlawedFreqTx.run_flawed_frequency_processing("69317163492948606335995924319873", 100)
  "52432133" 
  """
  @spec run_flawed_frequency_processing(String.t(), integer, integer) :: String.t()
  def run_flawed_frequency_processing(message, iterations, offset \\ 0) do
    message
    |> String.split(~r//, trim: true)
    |> _run_flawed_frequency_processing(iterations, offset)
    |> Enum.join("")
  end

  @spec _run_flawed_frequency_processing([String.t()], integer, integer) :: [String.t()]
  defp _run_flawed_frequency_processing(message, iterations, offset) when iterations <= 0 do
    message
    |> Enum.drop(offset)
    |> Enum.take(8)
  end

  defp _run_flawed_frequency_processing(message, iterations, offset) do
    # IO.inspect({iterations, message}, label: "\niter", width: :infinity)
    phase_output_message =
      message
      |> Enum.with_index(1)
      # In each phase, a new list is constructed with the same length as the input list.
      |> Enum.map(
        fn {v, i} ->
          repeating_pattern =
            @base_pattern
            # repeat each value in the pattern a number of times equal to the position
            # in the output list being considered. Repeat once for the first element, [etc.]
            |> Enum.flat_map(fn x -> Stream.cycle([x]) |> Enum.take(i) end)
            |> Stream.cycle()
            # When applying the pattern, skip the very first value exactly once.
            |> Stream.drop(1)

          # each element in the output array uses all of the same input array elements;
          # element in the new list is built by multiplying every value in the input list
          # by a value in a repeating pattern and then adding up the results
          Stream.zip(message, repeating_pattern)
          # |> IO.inspect(label: "\nzip(#{i})")
          # https://elixir-lang.org/getting-started/case-cond-and-if.html#case
          |> Enum.reduce(
            "0",
            fn
              {"0", _}, acc -> acc

              {_, 0}, acc -> acc

              # negative value -- if any -- always in second arg;
              # input digit always non-negative
              {d, 1}, acc ->
                least_significant_digit_add(d, acc)

              {d, -1}, acc ->
                # exploit commutativity and distributivity for shorter lookup table
                # negative value -- if any -- always in second arg;
                # input digit always non-negative
                case acc do
                  # NOTE -a - b = -(a + b)
                  # XXX -9 -5 = -(9 + 5) = -12 ... -2
                  #                   then -12 + 3 = -9
                  #                    but  -2 + 3 = (3 + -2) = 1
                  <<@minus::8, abs_acc_code::8>> ->
                    case least_significant_digit_add(<<abs_acc_code>>, d) do
                      # avoid "-0" ambiguity
                      "0" -> "0"
                       x -> "-#{x}"
                    end

                  _ ->
                    least_significant_digit_add(acc, "-#{d}")
                end
            end
          )
          |> case do
            <<@minus::8, digit_code::8>> -> <<digit_code>>
            digit -> digit
          end
        end
      )

    # This new list is also used as the input for the next phase.
    phase_output_message
    # |> IO.inspect(label: "\nout")
    |> _run_flawed_frequency_processing(iterations - 1, offset)
  end

  #
  # custom arithmetic to avoid expensive arbitrary-precision of standard library
  # calculate only least-significant digit of addition/subtraction result (by lookup)
  #
  # https://en.wikipedia.org/wiki/Modulo_operation#Properties_(identities)
  # mod is distributive over addition and multiplication
  #

  @spec least_significant_digit_add(String.t(), String.t()) :: String.t()
  defp least_significant_digit_add(digit, incr) do
    case {digit, incr} do
      {"0", "-9"} -> "-9"
      {"1", "-9"} -> "-8"
      {"2", "-9"} -> "-7"
      {"3", "-9"} -> "-6"
      {"4", "-9"} -> "-5"
      {"5", "-9"} -> "-4"
      {"6", "-9"} -> "-3"
      {"7", "-9"} -> "-2"
      {"8", "-9"} -> "-1"
      {"9", "-9"} -> "0"

      {"0", "-8"} -> "-8"
      {"1", "-8"} -> "-7"
      {"2", "-8"} -> "-6"
      {"3", "-8"} -> "-5"
      {"4", "-8"} -> "-4"
      {"5", "-8"} -> "-3"
      {"6", "-8"} -> "-2"
      {"7", "-8"} -> "-1"
      {"8", "-8"} -> "0"
      {"9", "-8"} -> "1"

      {"0", "-7"} -> "-7"
      {"1", "-7"} -> "-6"
      {"2", "-7"} -> "-5"
      {"3", "-7"} -> "-4"
      {"4", "-7"} -> "-3"
      {"5", "-7"} -> "-2"
      {"6", "-7"} -> "-1"
      {"7", "-7"} -> "0"
      {"8", "-7"} -> "1"
      {"9", "-7"} -> "2"

      {"0", "-6"} -> "-6"
      {"1", "-6"} -> "-5"
      {"2", "-6"} -> "-4"
      {"3", "-6"} -> "-3"
      {"4", "-6"} -> "-2"
      {"5", "-6"} -> "-1"
      {"6", "-6"} -> "0"
      {"7", "-6"} -> "1"
      {"8", "-6"} -> "2"
      {"9", "-6"} -> "3"

      {"0", "-5"} -> "-5"
      {"1", "-5"} -> "-4"
      {"2", "-5"} -> "-3"
      {"3", "-5"} -> "-2"
      {"4", "-5"} -> "-1"
      {"5", "-5"} -> "0"
      {"6", "-5"} -> "1"
      {"7", "-5"} -> "2"
      {"8", "-5"} -> "3"
      {"9", "-5"} -> "4"

      {"0", "-4"} -> "-4"
      {"1", "-4"} -> "-3"
      {"2", "-4"} -> "-2"
      {"3", "-4"} -> "-1"
      {"4", "-4"} -> "0"
      {"5", "-4"} -> "1"
      {"6", "-4"} -> "2"
      {"7", "-4"} -> "3"
      {"8", "-4"} -> "4"
      {"9", "-4"} -> "5"

      {"0", "-3"} -> "-3"
      {"1", "-3"} -> "-2"
      {"2", "-3"} -> "-1"
      {"3", "-3"} -> "0"
      {"4", "-3"} -> "1"
      {"5", "-3"} -> "2"
      {"6", "-3"} -> "3"
      {"7", "-3"} -> "4"
      {"8", "-3"} -> "5"
      {"9", "-3"} -> "6"

      {"0", "-2"} -> "-2"
      {"1", "-2"} -> "-1"
      {"2", "-2"} -> "0"
      {"3", "-2"} -> "1"
      {"4", "-2"} -> "2"
      {"5", "-2"} -> "3"
      {"6", "-2"} -> "4"
      {"7", "-2"} -> "5"
      {"8", "-2"} -> "6"
      {"9", "-2"} -> "7"

      {"0", "-1"} -> "-1"
      {"1", "-1"} -> "0"
      {"2", "-1"} -> "1"
      {"3", "-1"} -> "2"
      {"4", "-1"} -> "3"
      {"5", "-1"} -> "4"
      {"6", "-1"} -> "5"
      {"7", "-1"} -> "6"
      {"8", "-1"} -> "7"
      {"9", "-1"} -> "8"

      {"0", "0"} -> "0"
      {"1", "0"} -> "1"
      {"2", "0"} -> "2"
      {"3", "0"} -> "3"
      {"4", "0"} -> "4"
      {"5", "0"} -> "5"
      {"6", "0"} -> "6"
      {"7", "0"} -> "7"
      {"8", "0"} -> "8"
      {"9", "0"} -> "9"

      {"0", "1"} -> "1"
      {"1", "1"} -> "2"
      {"2", "1"} -> "3"
      {"3", "1"} -> "4"
      {"4", "1"} -> "5"
      {"5", "1"} -> "6"
      {"6", "1"} -> "7"
      {"7", "1"} -> "8"
      {"8", "1"} -> "9"
      {"9", "1"} -> "0"

      {"0", "2"} -> "2"
      {"1", "2"} -> "3"
      {"2", "2"} -> "4"
      {"3", "2"} -> "5"
      {"4", "2"} -> "6"
      {"5", "2"} -> "7"
      {"6", "2"} -> "8"
      {"7", "2"} -> "9"
      {"8", "2"} -> "0"
      {"9", "2"} -> "1"

      {"0", "3"} -> "3"
      {"1", "3"} -> "4"
      {"2", "3"} -> "5"
      {"3", "3"} -> "6"
      {"4", "3"} -> "7"
      {"5", "3"} -> "8"
      {"6", "3"} -> "9"
      {"7", "3"} -> "0"
      {"8", "3"} -> "1"
      {"9", "3"} -> "2"

      {"0", "4"} -> "4"
      {"1", "4"} -> "5"
      {"2", "4"} -> "6"
      {"3", "4"} -> "7"
      {"4", "4"} -> "8"
      {"5", "4"} -> "9"
      {"6", "4"} -> "0"
      {"7", "4"} -> "1"
      {"8", "4"} -> "2"
      {"9", "4"} -> "3"

      {"0", "5"} -> "5"
      {"1", "5"} -> "6"
      {"2", "5"} -> "7"
      {"3", "5"} -> "8"
      {"4", "5"} -> "9"
      {"5", "5"} -> "0"
      {"6", "5"} -> "1"
      {"7", "5"} -> "2"
      {"8", "5"} -> "3"
      {"9", "5"} -> "4"

      {"0", "6"} -> "6"
      {"1", "6"} -> "7"
      {"2", "6"} -> "8"
      {"3", "6"} -> "9"
      {"4", "6"} -> "0"
      {"5", "6"} -> "1"
      {"6", "6"} -> "2"
      {"7", "6"} -> "3"
      {"8", "6"} -> "4"
      {"9", "6"} -> "5"

      {"0", "7"} -> "7"
      {"1", "7"} -> "8"
      {"2", "7"} -> "9"
      {"3", "7"} -> "0"
      {"4", "7"} -> "1"
      {"5", "7"} -> "2"
      {"6", "7"} -> "3"
      {"7", "7"} -> "4"
      {"8", "7"} -> "5"
      {"9", "7"} -> "6"

      {"0", "8"} -> "8"
      {"1", "8"} -> "9"
      {"2", "8"} -> "0"
      {"3", "8"} -> "1"
      {"4", "8"} -> "2"
      {"5", "8"} -> "3"
      {"6", "8"} -> "4"
      {"7", "8"} -> "5"
      {"8", "8"} -> "6"
      {"9", "8"} -> "7"

      {"0", "9"} -> "9"
      {"1", "9"} -> "0"
      {"2", "9"} -> "1"
      {"3", "9"} -> "2"
      {"4", "9"} -> "3"
      {"5", "9"} -> "4"
      {"6", "9"} -> "5"
      {"7", "9"} -> "6"
      {"8", "9"} -> "7"
      {"9", "9"} -> "8"
    end
  end
end
