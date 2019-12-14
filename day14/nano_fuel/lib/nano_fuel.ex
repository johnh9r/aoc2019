defmodule NanoFuel do
  @moduledoc """
  given set of quantified chemical equations, determine minimum number
  of units of of ORE (= raw input) required to produce one unit of FUEL

  ## ideas
  * expanding wavefront (breadth-first)?
  * dynamic programming (i.e. cache partial results for later recombination)?
  * https://en.wikipedia.org/wiki/And%E2%80%93or_tree
  * post-order traversal: starting from FUEL
  * [A* search algorithm](https://en.wikipedia.org/wiki/A*_search_algorithm)
  * pull (FUEL seeks ingredients)  _vs_  push (ORE offers higher synthesis products)

  ## assumptions
  * target is always exactly 1 FUEL
  * input is DAG and connected
  * input has single root node FUEL
  * all quantities are integers
  """

  @doc """
  # 1 FUEL
  #   |
  #   \_(1:7)_A_________________________(10:10)_ORE
  #   \_(1:1)_E                        / |
  #           \_(1:7)_A_______________/  |
  #           \_(1:1)_D              /   |
  #                   \_(1:7)_A_____/    |
  #                   \_(1:1)_C          |
  #                           \_(1:7)_A__+
  #                           \_(1:1)_B
  #                                   \_(1:1)_ORE
  #
  # BFS: paths from root (FUEL) to each leaf (ORE ?!)
  # for each candidate
  #
  # 1 FUEL = 7A + (7A + (7A + (7A + 1_ORE))) = (10_ORE + 10_ORE + 10_ORE) + 1_ORE = 31_ORE
  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 10 ORE => 10 A
  ...> 1 ORE => 1 B
  ...> 7 A, 1 B => 1 C
  ...> 7 A, 1 C => 1 D
  ...> 7 A, 1 D => 1 E
  ...> 7 A, 1 E => 1 FUEL
  ...> })
  31
  """
  @spec calc_minimum_ore_for_fuel(String.t()) :: integer
  def calc_minimum_ore_for_fuel(equations) do
    reaction_edges =
      parse(equations)
      # [
      #   {{10, :a},    [{10, :ore}]},
      #   { {1, :b},    [{ 1, :ore}]},
      #   { {1, :c},    [{ 7, :a}, {1, :b}]},
      #   { {1, :d},    [{ 7, :a}, {1, :c}]},
      #   { {1, :e},    [{ 7, :a}, {1, :d}]},
      #   { {1, :fuel}, [{ 7, :a}, {1, :e}]}
      # ]
      |> Enum.flat_map(
        fn {{prod_quant, prod_kind}, quant_ingreds} ->
          quant_ingreds
          |> Enum.map(
            fn {ingred_quant, ingred_kind} ->
              # XXX ratio (of integers) may not be accurately representable as float (edge weight)
              Graph.Edge.new(prod_kind, ingred_kind, label: {prod_quant, ingred_quant})
            end
          )
        end
      )
      |> IO.inspect(label: "\nes")

    graph =
      Graph.new()
      |> Graph.add_edges(reaction_edges)

    graph
    |> Graph.Pathfinding.all(:fuel, :ore)
    |> IO.inspect()
  end

  @doc """
  transform "7 A, 1 B => 1 C" into { {1, "C"},  [{7, "A"}, {1, "B"}] }
  """
  @spec parse(String.t()) :: [{{integer, String.t()}, [{integer, String.t()}]}]
  def parse(equations) do
    equations
    |> String.trim()
    |> String.split(~r/\n/, trim: true)
    # per reaction equation
    |> Enum.map(
      fn s ->
        [left, right] = String.split(s, ~r/=>/)

        product_from_ingredients =
          [
            right |
            left |> String.split(~r/,/, trim: true)
          ]
          |> Enum.map(
            fn quantified_substance ->
              [q, s] = String.split(quantified_substance)
              {
                q |> String.to_integer(),
                s |> String.downcase() |> String.to_atom()
              }
            end
          )

        {{_quantity, _product}, _ingredients} = List.pop_at(product_from_ingredients, 0)
      end
    )
  end
end
