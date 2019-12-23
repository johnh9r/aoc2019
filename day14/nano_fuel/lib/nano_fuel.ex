defmodule NanoFuel do
  @moduledoc """
  given set of quantified chemical equations, determine minimum number
  of units of of ORE (= raw input) required to produce one unit of FUEL

  ## notes
  * "Almost every chemical is produced by exactly one reaction;
      the only exception, ORE, is the raw material input to the entire process
      and is not produced by a reaction."

  ## assumptions
  * target is always exactly 1 FUEL
  * input is DAG and connected
  * input has single root node FUEL
  * all quantities are integers
  * no undefined products (i.e. w/o synthesis equation)
  """

  @doc """
  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 10 ORE => 10 A
  ...> 1 ORE => 1 B
  ...> 7 A, 1 B => 1 C
  ...> 7 A, 1 C => 1 D
  ...> 7 A, 1 D => 1 E
  ...> 7 A, 1 E => 1 FUEL
  ...> })
  31

  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 9 ORE => 2 A
  ...> 8 ORE => 3 B
  ...> 7 ORE => 5 C
  ...> 3 A, 4 B => 1 AB
  ...> 5 B, 7 C => 1 BC
  ...> 4 C, 1 A => 1 CA
  ...> 2 AB, 3 BC, 4 CA => 1 FUEL
  ...> })
  168

  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 157 ORE => 5 NZVS
  ...> 165 ORE => 6 DCFZ
  ...> 44 XJWVT, 5 KHKGT, 1 QDVJ, 29 NZVS, 9 GPVTF, 48 HKGWZ => 1 FUEL
  ...> 12 HKGWZ, 1 GPVTF, 8 PSHF => 9 QDVJ
  ...> 179 ORE => 7 PSHF
  ...> 177 ORE => 5 HKGWZ
  ...> 7 DCFZ, 7 PSHF => 2 XJWVT
  ...> 165 ORE => 2 GPVTF
  ...> 3 DCFZ, 7 NZVS, 5 HKGWZ, 10 PSHF => 8 KHKGT
  ...> })
  13_312

  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 2 VPVL, 7 FWMGM, 2 CXFTF, 11 MNCFX => 1 STKFG
  ...> 17 NVRVD, 3 JNWZP => 8 VPVL
  ...> 53 STKFG, 6 MNCFX, 46 VJHF, 81 HVMC, 68 CXFTF, 25 GNMV => 1 FUEL
  ...> 22 VJHF, 37 MNCFX => 5 FWMGM
  ...> 139 ORE => 4 NVRVD
  ...> 144 ORE => 7 JNWZP
  ...> 5 MNCFX, 7 RFSQX, 2 FWMGM, 2 VPVL, 19 CXFTF => 3 HVMC
  ...> 5 VJHF, 7 MNCFX, 9 VPVL, 37 CXFTF => 6 GNMV
  ...> 145 ORE => 6 MNCFX
  ...> 1 NVRVD => 8 CXFTF
  ...> 1 VJHF, 6 MNCFX => 4 RFSQX
  ...> 176 ORE => 6 VJHF
  ...> })
  180_697

  iex> NanoFuel.calc_minimum_ore_for_fuel(~s{
  ...> 171 ORE => 8 CNZTR
  ...> 7 ZLQW, 3 BMBT, 9 XCVML, 26 XMNCP, 1 WPTQ, 2 MZWV, 1 RJRHP => 4 PLWSL
  ...> 114 ORE => 4 BHXH
  ...> 14 VRPVC => 6 BMBT
  ...> 6 BHXH, 18 KTJDG, 12 WPTQ, 7 PLWSL, 31 FHTLT, 37 ZDVW => 1 FUEL
  ...> 6 WPTQ, 2 BMBT, 8 ZLQW, 18 KTJDG, 1 XMNCP, 6 MZWV, 1 RJRHP => 6 FHTLT
  ...> 15 XDBXC, 2 LTCX, 1 VRPVC => 6 ZLQW
  ...> 13 WPTQ, 10 LTCX, 3 RJRHP, 14 XMNCP, 2 MZWV, 1 ZLQW => 1 ZDVW
  ...> 5 BMBT => 4 WPTQ
  ...> 189 ORE => 9 KTJDG
  ...> 1 MZWV, 17 XDBXC, 3 XCVML => 2 XMNCP
  ...> 12 VRPVC, 27 CNZTR => 2 XDBXC
  ...> 15 KTJDG, 12 BHXH => 5 XCVML
  ...> 3 BHXH, 2 VRPVC => 7 MZWV
  ...> 121 ORE => 7 VRPVC
  ...> 7 XCVML => 6 RJRHP
  ...> 5 BHXH, 4 VRPVC => 5 LTCX
  ...> })
  2_210_736
  """
  @spec calc_minimum_ore_for_fuel(String.t()) :: integer
  def calc_minimum_ore_for_fuel(equations) do
    reaction_edges =
      parse(equations)
      |> Enum.flat_map(
        fn {{prod_quant, prod_kind}, quant_ingreds} ->
          quant_ingreds
          |> Enum.map(
            fn {ingred_quant, ingred_kind} ->
              Graph.Edge.new(prod_kind, ingred_kind, label: {prod_quant, ingred_quant})
            end
          )
        end
      )

    graph =
      Graph.new()
      |> Graph.add_edges(reaction_edges)

    resolve_ingredients(graph, %{:fuel => 1})
    |> IO.inspect(label: "\nresult")
    |> (fn {%{:ore => n} = acc_used, _} -> n end).()
  end

  @spec resolve_ingredients(Graph.t(), map) :: {map, map}
  def resolve_ingredients(_graph, %{:ore => n}) do
    # most basic ingredient always obtainable in exact quantity (w/o anything spare)
    {%{:ore => n}, %{}}
  end

  def resolve_ingredients(graph, prod_quant) do
    # built-in sanity check: single synthesis target (key-value pair)
    [{product, quantity}] = Enum.into(prod_quant, [])
    IO.inspect({product, quantity}, label: "\nr_i(want)")

    Graph.out_neighbors(graph, product)
    |> Enum.sort_by(fn pre -> (Graph.get_shortest_path(graph, pre, :ore) || []) |> Kernel.length() end)
    |> Enum.reverse()
    # |> IO.inspect(label: "\nr_i(ngh)")
    |> Enum.reduce(
      {%{}, %{}},
      fn precursor, {acc_used, acc_spare} ->
        # at most one connection between any two nodes
        [%Graph.Edge{label: {q_prod_out, q_pre_in}}] = Graph.edges(graph, product, precursor)
        # IO.inspect({product, q_prod_out, q_pre_in, precursor}, label: "\nr_i(ratio)")
        n_repeat = ceil(quantity / q_prod_out)
        q_pre_req = n_repeat * q_pre_in
        q_prod_spare = n_repeat * q_prod_out - quantity

        case Map.get(acc_spare, precursor, 0) >= q_pre_in do
          # either have enough precursor spare (from earlier reactions) ...
          true ->
            {
              # precursor usage already accounted when spare product was created
              # Map.get_and_update(acc_used, precursor, fn value -> {value, (value || 0) + q_pre_in} end) |> Kernel.elem(1),
              acc_used,

              # TODO rewrite w/ Map.merge/3
              acc_spare
              |> Map.get_and_update(precursor, fn value -> {value, value - q_pre_in} end) |> Kernel.elem(1)
            }
            |> IO.inspect(label: "\nr_i(spare)")

          _ ->
            # ... or else need to synthesise
            {synth_used, synth_spare} = resolve_ingredients(graph, %{precursor => n_repeat * q_pre_in})

            # never less produced than required, ...
            case q_prod_spare > 0 do
              # ... but record any excess separately
              true -> 
                {
                  acc_used
                  |> Map.merge(synth_used, fn _k, v1, v2 -> v1 + v2 end),

                  acc_spare
                  |> Map.merge(synth_spare, fn _k, v1, v2 -> v1 + v2 end)
                  |> Map.merge(%{product => q_prod_spare}, fn _k, v1, v2 -> v1 + v2 end)
                }

              _ ->
                {
                  acc_used
                  |> Map.merge(synth_used, fn _k, v1, v2 -> v1 + v2 end),

                  acc_spare
                  |> Map.merge(synth_spare, fn _k, v1, v2 -> v1 + v2 end)
                }
            end
            |> IO.inspect(label: "\nr_i(synth)")
        end
      end
    )
  end

  # transform "7 A, 1 B => 1 C" into { {1, "C"},  [{7, "A"}, {1, "B"}] }
  @spec parse(String.t()) :: [{{integer, String.t()}, [{integer, String.t()}]}]
  defp parse(equations) do
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
