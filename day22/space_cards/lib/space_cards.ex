defmodule SpaceCards do
  @moduledoc """
  repeatedly shuffle deck of cards by list of given parameterised techniques

  ... focusing on position of single nominated card only!
  """

  @doc """
  long result: [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques("deal into new stack", 10, 3)
  6

  long result: [3, 4, 5, 6, 7, 8, 9, 0, 1, 2]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques("cut 3", 10, 1)
  8

  long result: [6, 7, 8, 9, 0, 1, 2, 3, 4, 5]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques("cut -4", 10, 2)
  6

  long result: [0, 7, 4, 1, 8, 5, 2, 9, 6, 3]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques("deal with increment 3", 10, 7)
  1

  long result: [0, 3, 6, 9, 2, 5, 8, 1, 4, 7]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques(~s{
  ...>   deal with increment 7
  ...>   deal into new stack
  ...>   deal into new stack
  ...>   },
  ...>   10, 8)
  6

  long result: [3, 0, 7, 4, 1, 8, 5, 2, 9, 6]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques(~s{
  ...>   cut 6
  ...>   deal with increment 7
  ...>   deal into new stack
  ...>   },
  ...>   10, 4)
  3

  long result: [6, 3, 0, 7, 4, 1, 8, 5, 2, 9]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques(~s{
  ...>   deal with increment 7
  ...>   deal with increment 9
  ...>   cut -2
  ...>   },
  ...>   10, 2)
  8

  long result: [9, 2, 5, 8, 1, 4, 7, 0, 3, 6]
  iex> SpaceCards.shuffle_by_single_card_tracing_techniques(~s{
  ...>   deal into new stack
  ...>   cut -2
  ...>   deal with increment 7
  ...>   cut 8
  ...>   cut -4
  ...>   deal with increment 7
  ...>   cut 3
  ...>   deal with increment 9
  ...>   deal with increment 3
  ...>   cut -1
  ...>   },
  ...>   10, 5)
  2
  """
  @spec shuffle_by_single_card_tracing_techniques(String.t(), integer, integer) :: integer
  def shuffle_by_single_card_tracing_techniques(techniques, deck_size, target_card) do
    techniques
    |> String.trim()
    |> String.split(~r<\n>, trim: true)
    |> Enum.reduce(
      # starting with ordered deck, so Card 1234 is at index 1234 (and Card 0 at index 0)
      target_card,
      fn curr_tech, card_idx ->
        # replace "accumulator" completely with revised position
        single_card_tracing_technique_for(curr_tech).(deck_size, card_idx)
      end
    )
  end

  @spec single_card_tracing_technique_for(String.t()) :: (integer, integer -> integer)
  def single_card_tracing_technique_for(tech) do
    {parameter, tokens} =
      tech
      |> String.split()
      |> List.pop_at(-1)

    case tokens do
      ["deal", "into", "new"] ->
        # 0 1 2 3 4 5 6 7 8 9
        # 9 8 7 6 5 4 3 2 1 0
        fn deck_sz, c_idx-> (deck_sz - 1) - c_idx  end

      ["cut"] ->
        param = String.to_integer(parameter)
        fn deck_sz, c_idx ->
          leading_cnt =
            case param > 0 do
              true -> param
              _ -> deck_sz + param
            end
          trailing_cnt = deck_sz - leading_cnt
          case c_idx < leading_cnt do
            # 0 1 2|3 4 5 6 7 8 9  w/ cut(3)
            # 3 4 5 6 7 7 8+0 1 2
            true -> trailing_cnt + c_idx
            # 0 1 2 3 4 5|6 7 8 9  w/ cut(-4)
            # 6 7 8 9+0 1 2 3 4 5
            _ -> c_idx - leading_cnt
          end
        end

      ["deal", "with", "increment"] ->
        param = String.to_integer(parameter)
        if param < 1, do: raise ArgumentError, message: "cannot deal with non-positive increment"
        # 0 1 2 3 4 5 6 7 8 9  w/ incr(3)
        # 0 7 4 1 8 5 2 9 6 3
        fn deck_sz, c_idx -> Integer.mod(param * c_idx, deck_sz) end
    end
  end

  #
  # naive implementation (viable only for first part of challenge)
  #

  @doc """
  iex> SpaceCards.shuffle_by_techniques("deal into new stack", 10)
  [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]

  iex> SpaceCards.shuffle_by_techniques("cut 3", 10)
  [3, 4, 5, 6, 7, 8, 9, 0, 1, 2]

  iex> SpaceCards.shuffle_by_techniques("cut -4", 10)
  [6, 7, 8, 9, 0, 1, 2, 3, 4, 5]

  iex> SpaceCards.shuffle_by_techniques("deal with increment 3", 10)
  [0, 7, 4, 1, 8, 5, 2, 9, 6, 3]

  iex> SpaceCards.shuffle_by_techniques(~s{
  ...>   deal with increment 7
  ...>   deal into new stack
  ...>   deal into new stack
  ...>   },
  ...>   10)
  [0, 3, 6, 9, 2, 5, 8, 1, 4, 7]

  iex> SpaceCards.shuffle_by_techniques(~s{
  ...>   cut 6
  ...>   deal with increment 7
  ...>   deal into new stack
  ...>   },
  ...>   10)
  [3, 0, 7, 4, 1, 8, 5, 2, 9, 6]

  iex> SpaceCards.shuffle_by_techniques(~s{
  ...>   deal with increment 7
  ...>   deal with increment 9
  ...>   cut -2
  ...>   },
  ...>   10)
  [6, 3, 0, 7, 4, 1, 8, 5, 2, 9]

  iex> SpaceCards.shuffle_by_techniques(~s{
  ...>   deal into new stack
  ...>   cut -2
  ...>   deal with increment 7
  ...>   cut 8
  ...>   cut -4
  ...>   deal with increment 7
  ...>   cut 3
  ...>   deal with increment 9
  ...>   deal with increment 3
  ...>   cut -1
  ...>   },
  ...>   10)
  [9, 2, 5, 8, 1, 4, 7, 0, 3, 6]
  """
  @spec shuffle_by_techniques(String.t(), integer) :: [integer]
  def shuffle_by_techniques(techniques, ordered_deck_size) do
    deck =
      Range.new(0, ordered_deck_size - 1)
      |> Enum.into([])

    techniques
    |> String.trim()
    |> String.split(~r<\n>, trim: true)
    |> Enum.reduce(
      deck,
      fn curr_tech, acc ->
        # replace "accumulator" completely with reordered deck
        technique_for(curr_tech).(acc)
      end
    )
  end

  # TODO explore beyond naive impl w/ list;  e.g. MapSet instead?
  @spec technique_for(String.t) :: ([integer] -> [integer])
  defp technique_for(tech) do
    {parameter, tokens} =
      tech
      |> String.split()
      |> List.pop_at(-1)

    case tokens do
      ["deal", "into", "new"] ->
        fn deck -> deck |> Enum.reverse() end
      ["cut"] ->
        param = String.to_integer(parameter)
        fn deck -> {leading, trailing} = deck |> Enum.split(param); trailing ++ leading end
      ["deal", "with", "increment"] ->
        param = String.to_integer(parameter)
        if param < 1, do: raise ArgumentError, message: "cannot deal with non-positive increment"
        fn deck ->
          len = Kernel.length(deck)
          deck
          |> Enum.reduce(
            {Stream.cycle([nil]) |> Enum.take(len), 0},
            fn card, {target_deck, idx} = _acc -> {List.replace_at(target_deck, idx, card), Integer.mod(idx + param, len)} end
          )
          |> Kernel.elem(0)
        end
    end
  end
end
