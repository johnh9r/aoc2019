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
    all_keys = sanity_check(initial_positions, initial_velocities)

    simulation =
      1..num_time_steps
      |> Enum.reduce(
        [{0, initial_positions, initial_velocities}],
        fn t, [{_prev_t, prev_ps, prev_vs} | _] = acc ->
          vs = update_velocities(prev_vs, prev_ps) # |> IO.inspect(label: "\nvs")
          ps = update_positions(prev_ps, vs) # |> IO.inspect(label: "\nps")
          [{t, ps, vs} | acc]
        end
      )

    {final_positions, final_velocities} =
      simulation
      |> List.first()
      |> (fn {_t, ps, vs} -> {ps, vs} end).()

    # {
    #   # t
    #   1000,
    #   # positions
    #   %{
    #     # velocities
    #     callisto: {53, 56, 37},
    #     europa: {64, -85, 24},
    #     ganymede: {23, 8, 23},
    #     io: {-117, 2, -57},
    #   },
    #   # velocities
    #   %{
    #      callisto: {-5, 9, 3},
    #      europa: {-2, 0, -14},
    #      ganymede: {-9, -8, 10},
    #      io: {16, -1, 1}
    #    }
    # }

    # A moon's potential energy is the sum of the absolute values of its x, y, and z position coordinates.
    potential_energies =
      final_positions
      |> Enum.reduce(%{}, fn {k, {x, y, z}}, acc -> Map.put(acc, k, abs(x) + abs(y) + abs(z)) end)
    
    # A moon's kinetic energy is the sum of the absolute values of its velocity coordinates.
    kinetic_energies =
      final_velocities
      |> Enum.reduce(%{}, fn {k, {x, y, z}}, acc -> Map.put(acc, k, abs(x) + abs(y) + abs(z)) end)

    # IO.inspect({potential_energies, kinetic_energies}, label: "\n")
    # {
    #   %{callisto: 146, europa: 173, ganymede: 54, io: 176},
    #   %{callisto: 17, europa: 16, ganymede: 27, io: 18}
    # }

    total_energies =
      all_keys
      |> Enum.reduce(%{}, fn k, acc -> Map.put(acc, k, potential_energies[k] * kinetic_energies[k]) end)
      # |> IO.inspect(label: "\n")
      # %{callisto: 2482, europa: 2768, ganymede: 1458, io: 3168}
      
    total_system_energy =
      total_energies
      |> Enum.reduce(0, fn {_k, v}, acc -> acc + v end)
  end


  @doc """
  (1) update (+/-) past velocities (based on gravity between all pairs of bodies)
  """
  @spec update_velocities(%{required(atom) => {integer, integer, integer}}, %{required(atom) => {integer, integer, integer}}) :: %{required(atom) => {integer, integer, integer}}
  def update_velocities(vs, ps) do
    ps
    |> Map.keys()
    |> distinct_pairs()
    |> Enum.reduce(
      %{},
      fn {k_one, k_other}, acc ->
        delta_v = gravity_pull(ps[k_one], ps[k_other])

        acc
        |> Map.get_and_update(k_one, fn delta_vs -> {delta_vs, [delta_v | (delta_vs || [])]} end)
        |> (fn {_, acc} -> acc end).()
        |> Map.get_and_update(k_other, fn delta_vs -> {delta_vs, [neg3d(delta_v) | (delta_vs || [])]} end)
        |> (fn {_, acc} -> acc end).()
      end
    )
    # %{
    #   callisto: [{1, 1, -1}, {1, 1, 1}, {-1, 1, 1}],
    #   europa: [{1, 1, -1}, {1, 1, 1}, {1, -1, -1}],
    #   ganymede: [{1, 1, -1}, {-1, -1, -1}, {-1, -1, -1}],
    #   io: [{-1, -1, 1}, {-1, -1, 1}, {-1, -1, 1}]
    # }
    # = map of moons with list of velocity changes for each
    |> Enum.reduce(
      %{},
      fn {k, dvs}, acc ->
        Map.put(
          acc,
          k,
          dvs
          |> Enum.reduce(
            vs[k],
            fn dv, acc -> sum3d(acc, dv) end
          )
        )
      end
    )
  end

  @doc """
  (2) update past positions by applying current velocities
  """
  @spec update_positions(%{required(atom) => {integer, integer, integer}}, %{required(atom) => {integer, integer, integer}}) :: %{required(atom) => {integer, integer, integer}}
  def update_positions(prev_ps, vs) do
    vs
    |> Enum.reduce(
      prev_ps,
      fn {k, v}, acc ->
        {_, new_acc} =
          Map.get_and_update(
            acc,
            k,
            fn old_value -> {old_value, sum3d(old_value, v)} end
          )
        new_acc
      end
    )
  end

  @doc """
    On each axis (x, y, and z), the velocity of each moon changes by exactly +1 or -1 to pull the moons together.
    For example, if Ganymede has an x position of 3, and Callisto has a x position of 5, then
    Ganymede's x velocity changes by +1 (because 5 > 3) and Callisto's x velocity changes by -1 (because 3 < 5).
    However, if the positions on a given axis are the same, the velocity on that axis does not change for that pair of moons.
  """
  @spec gravity_pull({integer, integer, integer}, {integer, integer, integer}) :: {integer, integer, integer}
  def gravity_pull({_x1, _y1, _z1} = p_one, {_x2, _y2, _z2} = p_other) do
    Enum.zip(
      p_one |> Tuple.to_list(),
      p_other |> Tuple.to_list()
    )
    # NOTE deliberate swap of comparison arguments
    # {g, c} = {3, 5} -> {+1,-1} = {dv_g, dv_c}
    |> Enum.map(
      fn {k, n} = _axis_pair ->
        cmp3(n, k)
      end
    )
    |> List.to_tuple()
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

  defp neg3d({x,y,z}), do: {-x,-y,-z}

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
    positions |> Enum.map(fn {_k, v} -> tuple_size(v) end) |> Enum.reduce(3, fn n, acc -> acc == n end)
    velocities |> Enum.map(fn {_k, v} -> tuple_size(v) end) |> Enum.reduce(3, fn n, acc -> acc == n end)
    k_ps = positions |> Map.keys() |> Enum.sort()
    k_vs = velocities |> Map.keys() |> Enum.sort()
    if k_ps != k_vs, do: raise "incongruous data set"
    k_ps
  end
end
