defmodule JupiterMoons do
  @moduledoc """
  calculate total energy (= positional + kinetic) for 3-d system of planetary bodies
  after number of discrete time steps
  """

  @doc """
  iex> JupiterMoons.calc_total_energy(
  ...>   %{a: {17,5,1}, b: {-2,-8,8}, c: {7,-6,14}, d: {1,-10,4}},
  ...>   %{a: {0,0,0}, b: {0,0,0}, c: {0,0,0}, d: {0,0,0}},
  ...>   10
  ...> )
  179
  """
  @spec calc_total_energy(%{required(atom) => {integer, integer, integer}}, %{required(atom) => {integer, integer, integer}}, integer) :: integer
  def calc_total_energy(initial_positions, initial_velocities, num_time_steps) when num_time_steps >= 0 do
    sanity_check(initial_positions, initial_velocities)

    simulation =
      1..num_time_steps
      |> Enum.reduce(
        [{0, initial_positions, initial_velocities}],
        fn t, [{prev_t, prev_ps, prev_vs} | _] = acc ->
          vs = update_velocities(prev_ps)
          ps = update_positions(prev_ps, vs)
          [{t, ps, vs} | acc]
        end
      )

    # total_energy = potential_energy * kinetic_energy
  end

  @doc """
  (1) update (+/-) past velocities (based on gravity between all pairs of bodies)
  """
  @spec update_velocities(%{required(atom) => {integer, integer, integer}}) :: %{required(atom) => {integer, integer, integer}}
  def update_velocities(ps) do
    # TODO
    %{a: {1,1,1}, b: {1,1,1}, c: {1,1,1}, d: {1,1,1}}
  end

  @doc """
  (2) update past positions by applying current velocities
  """
  @spec update_positions(%{required(atom) => {integer, integer, integer}}, %{required(atom) => {integer, integer, integer}}) :: %{required(atom) => {integer, integer, integer}}
  def update_positions(prev_ps, vs) do
    prev_ps
    |> Map.keys()
    |> Enum.reduce(%{}, fn k, acc -> Map.put(acc, k, sum3d(prev_ps[k], vs[k])) end)
  end

  @doc """
  iex> JupiterMoons.distinct_pairs([:a, :b, :c])
  [{:a, :b}, {:a, :c}, {:b, :c}]
  """
  @spec distinct_pairs([atom]) :: [{atom, atom}]
  def distinct_pairs(ks) do
    ks
    |> Enum.reduce(
      MapSet.new(),
      fn k, acc ->
        unordered_pairs =
          ks
          |> Enum.map(
            fn k_prime ->
              case {k, k_prime} do
                {same, same} = _pair -> {}
                {one, other} = pair -> if !MapSet.member?(acc, {other, one}), do: pair, else: {}
              end
            end
          )
          |> Enum.reject(fn t -> tuple_size(t) == 0 end)

        MapSet.union(acc, MapSet.new(unordered_pairs))
      end
    )
    |> MapSet.to_list()
  end

  defp sum3d({u,v,w}, {x,y,z}), do: {u+x, v+y, w+z}

  # <=> "spaceship operator" (Ruby), a.k.a. "three-way comparison operator" (C++)
  defp cmp3(x, y) do
    case x < y do
      true -> -1
      _ ->
        case x > y do
          true -> 1
          _ -> 0
        end
    end
  end

  defp sanity_check(positions, velocities) do
    n_ps = map_size(positions)
    n_vs = map_size(velocities)
    n_ps = n_vs
    positions |> Enum.map(fn {k, v} -> tuple_size(v) end) |> Enum.reduce(3, fn n, acc -> acc == n end)
    velocities |> Enum.map(fn {k, v} -> tuple_size(v) end) |> Enum.reduce(3, fn n, acc -> acc == n end)
  end
end
