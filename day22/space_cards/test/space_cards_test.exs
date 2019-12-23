defmodule SpaceCardsTest do
  use ExUnit.Case
  doctest SpaceCards, only: [shuffle_by_single_card_tracing_techniques: 3]

  setup do
    my_insns = """
      deal with increment 55
      cut -6791
      deal with increment 9
      cut -5412
      deal with increment 21
      deal into new stack
      deal with increment 72
      cut -362
      deal with increment 24
      cut -5369
      deal with increment 22
      cut 731
      deal with increment 72
      cut 412
      deal into new stack
      deal with increment 22
      cut -5253
      deal with increment 73
      deal into new stack
      cut -6041
      deal into new stack
      cut 6605
      deal with increment 6
      cut 9897
      deal with increment 59
      cut -9855
      deal into new stack
      cut -7284
      deal with increment 7
      cut 332
      deal with increment 37
      deal into new stack
      deal with increment 43
      deal into new stack
      deal with increment 59
      cut 1940
      deal with increment 16
      cut 3464
      deal with increment 24
      cut -7766
      deal with increment 36
      cut -156
      deal with increment 18
      cut 8207
      deal with increment 33
      cut -393
      deal with increment 4
      deal into new stack
      cut -4002
      deal into new stack
      cut -8343
      deal into new stack
      deal with increment 70
      deal into new stack
      cut 995
      deal with increment 22
      cut 1267
      deal with increment 47
      cut -3161
      deal into new stack
      deal with increment 34
      cut -6221
      deal with increment 26
      cut 4956
      deal with increment 57
      deal into new stack
      cut -4983
      deal with increment 36
      cut -1101
      deal into new stack
      deal with increment 2
      cut 4225
      deal with increment 35
      cut -721
      deal with increment 17
      cut 5866
      deal with increment 40
      cut -531
      deal into new stack
      deal with increment 63
      cut -5839
      deal with increment 30
      cut 5812
      deal with increment 35
      deal into new stack
      deal with increment 46
      cut -5638
      deal with increment 60
      deal into new stack
      deal with increment 33
      cut -4690
      deal with increment 7
      cut 6264
      deal into new stack
      cut 8949
      deal into new stack
      cut -4329
      deal with increment 52
      cut 3461
      deal with increment 47
      """
 
    [
      techniques: my_insns,

      deck_size_pt1: 10_007,
      target_card_pt1: 2019,

      deck_size_pt2: 119_315_717_514_047,
      target_card_pt2: 2020
    ]
  end

  # NOTE: number of reps not computationally feasible; even at 1M iter/s, requiring >3y
  #
  @tag :challenge_pt2
  test "(part 2) correctly processes personal challenge", context do
    final_pos_target_card =
      1..101_741_582_076_661
      |> Enum.reduce(
        context[:target_card_pt2],
        fn _i, acc ->
          IO.inspect({_i, acc})
          SpaceCards.shuffle_by_single_card_tracing_techniques(
            context[:techniques],
            context[:deck_size_pt2],
            acc
          )
        end
      )
    # too high: 96_951_829_818_229
    assert final_pos_target_card == -1
  end

  @tag :challenge_pt1
  test "(part 1) correctly processes personal challenge", context do
    assert 4_096 == SpaceCards.shuffle_by_single_card_tracing_techniques(
      context[:techniques],
      context[:deck_size],
      context[:target_card_pt1]
    )
  end

  # @tag :challenge_pt1
  # test "(part 1) correctly processes personal challenge", context do
  #   result = SpaceCards.shuffle_by_techniques(context[:techniques], 10_007)
  #   assert Enum.find_index(result, fn x -> x == 2019 end) == 4_096
  # end
end
