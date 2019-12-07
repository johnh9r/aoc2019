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

  def count_orbit_transfers(orbits_tsv, this \\ :_you, that \\ :_san) do
    orbits = build_orbits(orbits_tsv)

    path_to_this = orbits |> _find_path_with_default(this, []) |> IO.inspect(limit: :infinity)
    path_to_that = orbits |> _find_path_with_default(that, []) |> IO.inspect(limit: :infinity)
  end

  @doc """
  iex> Orbits.total_orbits("COM)B B)C C)D D)E E)F B)G G)H D)I E)J J)K K)L")
  42
  """
  @spec total_orbits(String.t()) :: integer
  def total_orbits(orbits_tsv) do
    build_orbits(orbits_tsv)
    |> Enum.reduce(0, fn p, acc -> acc + tuple_size(p) - 1 end)
  end

  defp build_orbits(orbits_tsv) do
    forest =
      orbits_tsv
      |> String.split()
      |> Enum.reduce(
        Map.new(__ctor__: %{}, _com: %{}),
        fn orbit, tree -> insert_orbit(tree, String.split(orbit, ")")) end
      )

    {ctor, tree} = forest |> Map.pop(:__ctor__)

    assemble(tree, ctor)
    |> Orbits.traverse_breadth_first()
  end

  @spec assemble(map, map) :: map
  # cannot pattern match, since any map will match empty one
  def assemble(tree, branches) when map_size(branches) == 0 do
    tree
  end

  def assemble(tree, branches) do
    # pick random as-yet disconnected branch
    [k] = Map.keys(branches) |> Enum.shuffle() |> Enum.take(1)

    tree |> find_path(k)
    |> case do
        [] ->
          # try again with better luck (random key choice)
          assemble(tree, branches) 
        path ->
          {loose_branch, weeded_branches} = branches |> Map.pop(k)
          parent_path = path |> Enum.reverse() |> Enum.drop(1) |> Enum.reverse()
          Kernel.update_in(tree, parent_path, &(Map.put(&1, k, loose_branch)))
          |> assemble(weeded_branches) 
       end
  end

  # prepend underscore for valid Elixir atom without illegible quoting
  defp insert_orbit(tree, [parent | [child]]) do
    insert(
      tree,
      "_" <> parent |> String.downcase() |> String.to_atom(),
      "_" <> child |> String.downcase() |> String.to_atom()
    )
  end

  @doc """
  iex> Orbits.insert(%{_com: %{}}, :_com, :b)
  %{_com: %{b: %{}}}

  iex> Orbits.insert(%{_com: %{b: %{}}}, :b, :c)
  %{_com: %{b: %{c: %{}}}}

  iex> Orbits.insert(%{_com: %{b: %{c: %{}}}}, :b, :g)
  %{_com: %{b: %{c: %{}, g: %{}}}}

  iex> Orbits.insert(%{_com: %{b: %{c: %{}, g: %{}}}}, :g, :h)
  %{_com: %{b: %{c: %{}, g: %{h: %{}}}}}

  iex> Orbits.insert(%{__ctor__: %{}, _com: %{b: %{c: %{}}}}, :g, :h)
  %{__ctor__: %{g: %{h: %{}}}, _com: %{b: %{c: %{}}}}
  """
  @spec insert(map, atom, atom) :: map
  def insert(tree, parent, child) do
    # by problem definition, tree always contains top-level %{_com: %{}}
    tree
    |> find_path(parent)
    |> case do
         [] ->
           # save tree fragment for subsequent integration
           Kernel.update_in(tree, [:__ctor__], &(Map.put(&1, parent, Map.new([{child, %{}}]))))
         path ->
           Kernel.update_in(tree, path, &(Map.put(&1, child, %{})))
       end
  end

  @doc """
  iex> Orbits.find_path(%{_com: %{}}, :none_such)
  []

  iex> Orbits.find_path(%{_com: %{}}, :_com)
  [:_com]

  iex> Orbits.find_path(%{_com: %{b: %{c: %{}, g: %{h: %{}}}}}, :g)
  [:_com, :b, :g]

  iex> Orbits.find_path(%{_com: %{b: %{c: %{}, g: %{h: %{}}}}}, :h)
  [:_com, :b, :g, :h]
  """
  @spec find_path(map, atom) :: [atom]
  def find_path(tree, node) do
    traverse_breadth_first(tree)
    |> _find_path_with_default(node, [])
  end

  defp _find_path_with_default(orbits, node, default_value) do
    orbits
    # at least one node :_com
    |> Enum.find_value(
      default_value,
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

  iex> Orbits.traverse_breadth_first(%{_com: %{}})
  [{:_com}]

  iex> Orbits.traverse_breadth_first(%{_com: %{b: %{}}})
  [{:_com}, {:_com, :b}]

  iex> Orbits.traverse_breadth_first(%{_com: %{b: %{}, g: %{}}})
  [{:_com}, {:_com, :b}, {:_com, :g}]

  iex> Orbits.traverse_breadth_first(%{_com: %{b: %{c: %{}, g: %{h: %{}}}}})
  [{:_com}, {:_com, :b}, {:_com, :b, :c}, {:_com, :b, :g}, {:_com, :b, :g, :h}]
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
  # iex> Orbits.count_leaf_nodes(%{_com: %{b: %{c: %{}, g: %{h: %{}}}}})
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
