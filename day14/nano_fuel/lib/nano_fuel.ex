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
  @spec calc_max_fuel_from_ore(String.t(), integer) :: integer
  def calc_max_fuel_from_ore(equations, kq_ore_avail) do
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

    # see below, for rationale for using Agent
    {:ok, _stash_pid} =
      Agent.start_link(fn -> %{} end, name: __MODULE__)

    {lo, hi} = _calc_max_fuel_from_ore(graph, kq_ore_avail, 2_000_000, 4_000_000)
    IO.inspect({lo, hi}, label: "\nresult")

    lo
  end

  @spec _calc_max_fuel_from_ore(Graph.t(), integer, integer, integer) :: {integer, integer}
  defp _calc_max_fuel_from_ore(graph, kq_ore_avail, q_fuel_guess_lo, q_fuel_guess_hi) do
    # reset stash between attempts
    Agent.update(__MODULE__, fn _state -> %{} end)

    q_half_fuel_diff = div(q_fuel_guess_hi - q_fuel_guess_lo, 2)

    %{:ore => n} =
      resolve_ingredients(graph, %{:fuel => q_fuel_guess_lo + q_half_fuel_diff})

    cond do
      n < kq_ore_avail && q_half_fuel_diff > 0 -> _calc_max_fuel_from_ore(graph, kq_ore_avail, q_fuel_guess_lo + q_half_fuel_diff, q_fuel_guess_hi)
      n > kq_ore_avail && q_half_fuel_diff > 0 -> _calc_max_fuel_from_ore(graph, kq_ore_avail, q_fuel_guess_lo, q_fuel_guess_hi - q_half_fuel_diff)
      true -> {q_fuel_guess_lo, q_fuel_guess_hi}
    end
  end

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
  165
  
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

    # for sibling recursive calls to share stash, need Agent!
    # otherwise dependent on propagation of execess upwards to caller
    # before it can be reused (which may be too late);
    #
    # for ease of use, prefer named agent
    {:ok, _stash_pid} =
      Agent.start_link(fn -> %{} end, name: __MODULE__)

    %{:ore => n} =
      resolve_ingredients(graph, %{:fuel => 1})

    n
  end

  @spec resolve_ingredients(Graph.t(), map) :: map
  def resolve_ingredients(_graph, _prod_quant, _dbg_lvl \\ 0)

  def resolve_ingredients(_graph, %{:ore => n}, _dbg_lvl) do
    # most basic ingredient always obtainable in exact quantity (w/o anything spare)
    %{:ore => n}
  end

  def resolve_ingredients(graph, prod_quant, dbg_lvl) do
    # built-in sanity check: single synthesis target (key-value pair)
    [{product, quantity}] = Enum.into(prod_quant, [])
    log({product, quantity}, "want", dbg_lvl)

    # given: demand for 37 W (from superordinate equations),
    #         i.e. %{w => 37}, so product = :w and demand = 37
    #
    # given: "5 W <= 3 X + 8 Z" (for any actual synthesis that may be necessary)
    #
    #     product vs precursors
    #  q_prod_out    q_pre_in
    #
    #    a.k.a. W 5:3 X
    #           W 5:8 Z
    #
    # given: stash of 9 W (from earlier synthesis reactions)
    #
    # (1) check whether stash can partially or fully meet demand:
    #     (ore is never admitted to stash so will always be freshly mined in base case)
    #     reduce demand (quantity) by whatever is found in stash
    #     [here: unmet_demand = 37 - 9 = 28 (W)]
    #
    # (2a) if remaining demand is zero, return zero ore consumption to caller (finished)
    #
    # (2b) if remaining demand is non-zero, then proceed to synthesis,
    #     iterating over precursor substances  [here: X, Z]
    #     between stash supply and fresh synthesis, demand is always met
    #     (and assuming "1 FUEL <= ...", fuel can never be overproduced and stashed)
    #
    # (3) fundamentally, given reaction needs to run one or more times;
    #     it can meet remaining demand only in certain increments;
    #     it must never produce less than is in demand;
    #     it may inadvertently produce more product than is in demand,
    #     in which case any excess product is stashed
    #     [here:
    #         n_repeat = ceil(unmet_demand / q_prod_out) = ceil(28 / 5) = 6
    #         q_prod_excess = n_repeat * q_prod_out - unmet_demand = 6 * 5 - 28 = 2
    #     ]
    #
    # (4) for each precursor, calculate demand
    #     demand = n_repeat * q_pre_in
    #     [here:  demand_X = 6 * 3 = 18,  demand_Y = 6 * 8 = 48]
    #     each such subordinate demand is resolved recursively
    #     [here:  18 X or 48 Z, respectively, in place of 37 W -- repeat from top]
    #
    # (5) return cumulative ore consumption to caller

    # aggressively use stashed excess (if any):
    # even just to reduce (rather than fully eliminate) further production;
    # never mind if any excess reappears as by-product (for stashing);
    # no rounding yet: e.g. meet requirement exactly if stash allows
    q_prod_avail = use_any_spare(product, quantity, dbg_lvl)
    # guaranteed non-negative
    q_prod_req = quantity - q_prod_avail

    case q_prod_req do
      0 ->
        # (2a) nothing left to do, no ore consumed
        %{}

      _ ->
        # (2b) trigger synthesis of unmet demand
        synthesise(graph, product, q_prod_req, dbg_lvl)
    end
  end

  @spec synthesise(Graph.t(), atom, integer, integer) :: map
  defp synthesise(graph, product, product_quantity, dbg_lvl) do
    {q_prod_out, quant_precursors} = prep_synth_reaction(graph, product)

    # (3) may need to run reaction repeated,
    # e.g "4 A <= 18 ORE" can produce 4A, 8A, ..., 20A, ...
    # nearest bigger integer multiple of output quantum, e.g. 3 instead of 2.7818
    n_repeat =
      ceil(product_quantity / q_prod_out)
      |> log("rpt", dbg_lvl)

    synthesis_consumption =
      quant_precursors
      # iteratively, focus on each precursor substance in turn
      |> Enum.reduce(
        %{},
        fn {q_pre_in, precursor}, acc_used ->
          log({product, q_prod_out, q_pre_in, precursor}, "ratio", dbg_lvl)
          synth_used = resolve_ingredients(graph, %{precursor => n_repeat * q_pre_in}, dbg_lvl+1)

          acc_used
          |> Map.merge(synth_used, fn _k, v1, v2 -> v1 + v2 end)
        end
      )

    # (3) when all precursors can been produced and combined, then some excess product may have resulted (once)
    q_prod_spare =
      n_repeat * q_prod_out - product_quantity
      |> log("spare #{product}", dbg_lvl)

    stash_any_spare(product, q_prod_spare, dbg_lvl)

    synthesis_consumption
  end

  @spec prep_synth_reaction(Graph.t(), atom) :: {integer, [{integer, atom}]}
  defp prep_synth_reaction(graph, product) do
    Graph.out_neighbors(graph, product)
    |> Enum.sort_by(fn pre -> (Graph.get_shortest_path(graph, pre, :ore) || []) |> Kernel.length() end)
    |> Enum.reverse()
    |> Enum.map(
      fn precursor ->
        # at most one connection between any two nodes
        [%Graph.Edge{label: {q_prod_out, q_pre_in}}] = Graph.edges(graph, product, precursor)

        {q_prod_out, {q_pre_in, precursor}}
      end
    )
    |> Enum.reduce(
      {nil, []},
      fn {q_prod_out, {q_pre_in, precursor}}, {x, quant_precursors} = _acc ->
        q_prod_out =
          case {q_prod_out, x} do
            {n, nil} -> n
            {n, n} -> n
            _ -> raise RuntimeError, message: "inconsistent product quantity out of related precursor reactions"
          end

        {q_prod_out, [{q_pre_in, precursor} | quant_precursors]}
      end
    )
  end

  # lesser precursor substances were already correctly accounted during their (excess) production
  @spec use_any_spare(atom, integer, integer) :: integer
  # defp use_any_spare(_precursor, _q_max_req, _dbg_lvl \\ 0)

  # tacitly ignore attempt to find ore in stash (to which it is never added)
  defp use_any_spare(:ore, _q_max_req, _dbg_lvl), do: 0

  defp use_any_spare(precursor, q_max_req, dbg_lvl) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        q_spare_avail = Map.get(state, precursor)

        case q_spare_avail do
          nil ->
            log(nil, "miss #{precursor}", dbg_lvl)
            {0, state}

          _ ->
            q_spare_recycled = Kernel.min(q_spare_avail, q_max_req)

            {
              # substances remaining with zero quantity is harmless to accounting
              q_spare_recycled
              |> log("hit #{precursor}", dbg_lvl),

              Map.get_and_update(state, precursor, fn value -> {value, value - q_spare_recycled} end) |> Kernel.elem(1)
            }
        end
      end
    )
  end

  # by problem definition(?), reactions produce exactly one product
  # sum quantities if any excess already stashed for given substance
  @spec stash_any_spare(atom, integer, integer) :: :ok
  # defp stash_any_spare(_substance, _q_excess, _dbg_lvl \\ 0)

  defp stash_any_spare(_substance, q_excess, _dbg_lvl) when q_excess < 0, do: raise ArgumentError, message: "negative 'excess'"

  defp stash_any_spare(_substance, q_excess, _dbg_lvl) when q_excess == 0, do: :ok

  # tacitly ignore unnecessary attempts to stash ore (which is always readily available in unlimited quantities)
  defp stash_any_spare(:ore, _q_excess, _dbg_lvl), do: :ok

  defp stash_any_spare(:fuel, q_excess, _dbg_lvl), do: raise ArgumentError, message: "refusing to 'stash' (#{q_excess}) FUEL"

  defp stash_any_spare(substance, q_excess, dbg_lvl) do
    Agent.update(
      __MODULE__,
      fn state ->
        state
        |> Map.merge(%{substance => q_excess}, fn _k, v1, v2 -> v1 + v2 end)
        |> log("stashed", dbg_lvl)
      end
    )
  end

  # write (to IO) representation of given object with informative label and indented by call level
  #
  # starting: top-level
  #   en route: first level
  #     deep: second level
  #
  # able to tap into pipe (similar to IO.inspect)
  @spec log(String.t(), String.t(), integer) :: any

  # XXX no-op impl masks chatty impl below
  defp log(obj, _label, _nesting_level), do: obj

  defp log(obj, label, nesting_level) do
    msg = Kernel.inspect(obj, label: label)

    prefix =
      Stream.concat(["\n"], Stream.cycle(["  "]))
      |> Enum.take(1 + nesting_level)

    IO.write(:stderr, "#{prefix}#{label}: #{msg}")

    obj
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
