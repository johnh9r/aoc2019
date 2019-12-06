defmodule Orbits do
  @moduledoc """
  calculate total number of direct and indirect orbits from given input

  ##  assumptions
  * DAG (i.e. loops physically non-sensical)
  * no duplicates (which could inadvertently prune tree data structure)
  * names of heavenly bodies may be arbitrary length and characters

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
      Map.new(com: %{}),
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

  iex> Orbits.insert(%{com: %{com: %{b: %{}}}}, :b, :c)
  %{com: %{b: %{c: %{}}}}

  iex> Orbits.insert(%{com: %{b: %{c: %{}}}}, :b, :g)
  %{com: %{b: %{c: %{}, g: %{}}}}

  iex> Orbits.insert(%{com: %{b: %{c: %{}, g: %{}}}}, :g, :h)
  %{com: %{b: %{c: %{}, g: %{h: %{}}}}}
  """
  def insert(tree, parent, child) do
    # by problem definition, tree always contains top-level :com
    paths = traverse_breadth_first(tree)
    # TODO
    {}
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
