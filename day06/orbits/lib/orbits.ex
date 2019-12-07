defmodule Orbits do
  @moduledoc """
  calculate total number of direct and indirect orbits from given input

  ##  assumptions
  * DAG (e.g. no loops of mutually rotating pairs)
  * no duplicates (which could inadvertently prune tree data structure)
  * names of heavenly bodies may be arbitrary length and characters
  * input should be consumed and tree built in single pass (sic!)

  ##  observations
  * input order is arbitrary, i.e. parent nodes not necessarily created before their children

  ##  illustration
  ```
	  G - H       J - K - L
	 /           /
  COM - B - C - D - E - F
		 \
		  I
  ```
  """

  @doc """
  iex> Orbits.total_orbits("COM)B B)C C)D D)E E)F B)G G)H D)I E)J J)K K)L")
  42
  """
  @spec total_orbits(String.t()) :: integer
  def total_orbits(orbits_tsv) do
    orbits_tsv
    |> String.split()
    |> Enum.reduce(
      Map.new(_ctor_: %{}, com: %{}),
      fn orbit, tree -> insert_orbit(tree, String.split(orbit, ")")) end
    )
    |> Orbits.traverse_breadth_first()
    |> Kernel.length()
  end

  defp insert_orbit(tree, [parent | [child]]) do
    insert(
      tree,
      parent |> String.downcase() |> String.to_atom(),
      child |> String.downcase() |> String.to_atom()
    )
  end

  @doc """
  iex> Orbits.insert(%{com: %{}}, :com, :b)
  %{com: %{b: %{}}}

  iex> Orbits.insert(%{com: %{b: %{}}}, :b, :c)
  %{com: %{b: %{c: %{}}}}

  iex> Orbits.insert(%{com: %{b: %{c: %{}}}}, :b, :g)
  %{com: %{b: %{c: %{}, g: %{}}}}

  iex> Orbits.insert(%{com: %{b: %{c: %{}, g: %{}}}}, :g, :h)
  %{com: %{b: %{c: %{}, g: %{h: %{}}}}}

  iex> Orbits.insert(%{_ctor_: %{}, com: %{b: %{c: %{}}}}, :g, :h)
  %{_ctor_: %{g: %{h: %{}}}, com: %{b: %{c: %{}}}}
  """
  @spec insert(map, atom, atom) :: map
  def insert(tree, parent, child) do
    # by problem definition, tree always contains top-level %{com: %{}}
    tree
    |> find_path(parent)
    |> case do
         [] ->
           # save tree fragment for subsequent integration
           Kernel.update_in(tree, [:_ctor_], &(Map.put(&1, parent, Map.new([{child, %{}}]))))
         path ->
           Kernel.update_in(tree, path, &(Map.put(&1, child, %{})))
       end
  end

  @doc """
  iex> Orbits.find_path(%{com: %{}}, :none_such)
  []

  iex> Orbits.find_path(%{com: %{}}, :com)
  [:com]

  iex> Orbits.find_path(%{com: %{b: %{c: %{}, g: %{h: %{}}}}}, :g)
  [:com, :b, :g]

  iex> Orbits.find_path(%{com: %{b: %{c: %{}, g: %{h: %{}}}}}, :h)
  [:com, :b, :g, :h]
  """
  @spec find_path(map, atom) :: [atom]
  def find_path(tree, node) do
    traverse_breadth_first(tree)
    # at least one node :com
    |> Enum.find_value(
      [],
      fn t ->
        ns = t |> Tuple.to_list()
        case ns |> Enum.reverse() do
          [^node | _] -> ns
          _ -> false
        end
      end
    )
  end

  @doc """
  iex> Orbits.traverse_breadth_first(%{})
  []

  iex> Orbits.traverse_breadth_first(%{com: %{}})
  [{:com}]

  iex> Orbits.traverse_breadth_first(%{com: %{b: %{}}})
  [{:com}, {:com, :b}]

  iex> Orbits.traverse_breadth_first(%{com: %{b: %{}, g: %{}}})
  [{:com}, {:com, :b}, {:com, :g}]

  iex> Orbits.traverse_breadth_first(%{com: %{b: %{c: %{}, g: %{h: %{}}}}})
  [{:com}, {:com, :b}, {:com, :b, :c}, {:com, :b, :g}, {:com, :b, :g, :h}]
  """
  @spec traverse_breadth_first(map) :: []
  def traverse_breadth_first(tree) do
    _traverse_breadth_first(tree, [])
    # for empty tree, turn {} into [{}]
    |> List.wrap()
    # ignore first element {} from accumulator seed []
    |> Enum.drop(1)
    |> List.flatten()
    |> Enum.sort
    |> Enum.dedup()
  end

  defp _traverse_breadth_first(tree, acc) do
    if tree == %{} do
      # EXTRA
      # [:_ | acc]  |> List.to_tuple()
      acc |> List.to_tuple()
    else
      child_paths =
        Map.keys(tree)
        |> Enum.map(fn subnode -> _traverse_breadth_first(tree[subnode], acc ++ [subnode]) end)

      [List.to_tuple(acc), child_paths]
    end
  end

  # EXTRA
  #
  # @doc """
  # iex> Orbits.count_leaf_nodes(%{})
  # 0
  #
  # iex> Orbits.count_leaf_nodes(%{com: %{b: %{c: %{}, g: %{h: %{}}}}})
  # 2
  # """
  # @spec count_leaf_nodes(map) :: integer
  # def count_leaf_nodes(_tree) do
  #   traverse_breadth_first(tree)
  #   |> Enum.reduce(
  #     0,
  #     fn path, acc ->
  #       case path |> Tuple.to_list do
  #         [:_ | _] -> acc + 1
  #         _ -> acc
  #       end
  #     end
  #   )
  # end
end
