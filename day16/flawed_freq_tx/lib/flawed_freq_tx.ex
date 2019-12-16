defmodule FlawedFreqTx do
  @moduledoc """
  apply Flawed Frequency Processsing to input message for given number of iterations
  """

  @base_pattern [0, 1, 0, -1]

  @doc """
  iex> FlawedFreqTx.run_flawed_frequency_processing("12345678", 8)
  "01029498"


      80871224585914546619083218645595 becomes 24176176.
      19617804207202209144916044189917 becomes 73745418.
      69317163492948606335995924319873 becomes 52432133.

  iex> FlawedFreqTx.run_flawed_frequency_processing("80871224585914546619083218645595", 100)
  "24176176"

  iex> FlawedFreqTx.run_flawed_frequency_processing("19617804207202209144916044189917", 100)
  "73745418"

  iex> FlawedFreqTx.run_flawed_frequency_processing("69317163492948606335995924319873", 100)
  "52432133" 
  """
  @spec run_flawed_frequency_processing(String.t(), integer) :: String.t()
  def run_flawed_frequency_processing(message, iterations) when iterations <= 0, do: message

  def run_flawed_frequency_processing(message, iterations) do
    message_digits =
      message
      |> String.split(~r//, trim: true)
      |> Enum.map(&String.to_integer/1)

    IO.inspect({message_digits, iterations}, label: "\n")

    phase_output_message =
      message_digits
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
            |> Stream.drop(1)

            # When applying the pattern, skip the very first value exactly once.

          # ARGH -- impl of Enum.drop/1 cannot cope w/ infinite lists
          # [_ | repeating_pattern_shift_left_one] = repeating_pattern
          repeating_pattern_shift_left_one = repeating_pattern

          # each element in the output array uses all of the same input array elements;
          # element in the new list is built by multiplying every value in the input list
          # by a value in a repeating pattern and then adding up the results
          Stream.zip(message_digits, repeating_pattern_shift_left_one)
          |> IO.inspect(label: "\nzip(#{i})")
          |> Enum.reduce(
            0,
            fn {d, p}, acc -> acc + d * p end
          )
          # only the ones digit is kept
          |> Kernel.abs()
          |> Integer.mod(10)
        end
      )
      |> Enum.join("")

    # This new list is also used as the input for the next phase.
    run_flawed_frequency_processing(phase_output_message, iterations - 1)
  end
end
