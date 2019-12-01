defmodule FuelRecursion do
  @moduledoc """
  calculate sum of units of fuel required to launch collection of modules with given masses,
  taking into account that fuel itself has mass and requires more fuel
  """

  @doc """
  ## [Examples](https://adventofcode.com/2019/day/1)

  leaving summation to caller is less efficient but more transparent

  iex> FuelRecursion.self_supporting_fuel_units_for_mass(12)
  [2]

  iex> FuelRecursion.self_supporting_fuel_units_for_mass(1969)
  [5, 21, 70, 216, 654]

  iex> FuelRecursion.self_supporting_fuel_units_for_mass(100_756)
  [2, 12, 43, 135, 411, 1240, 3728, 11192, 33583]
  """
  @spec self_supporting_fuel_units_for_mass(integer) :: [integer]
  def self_supporting_fuel_units_for_mass(m) do
    _self_supporting_fuel_units_for_mass(m, [])
  end

  @spec _self_supporting_fuel_units_for_mass(integer, [integer]) :: [integer]
  defp _self_supporting_fuel_units_for_mass(m, acc) do
    fuel_unit = div(m, 3) - 2

    if fuel_unit > 0,
      do: _self_supporting_fuel_units_for_mass(fuel_unit, [fuel_unit | acc]),
      else: acc
  end

  @doc """
  iex> FuelRecursion.total_self_supporting_fuel([12, 1969, 100_756])
  51_314
  """
  @spec total_self_supporting_fuel([integer]) :: integer
  def total_self_supporting_fuel(ms) do
    Enum.map(ms, &self_supporting_fuel_units_for_mass/1)
    |> Enum.reduce(0, fn fs, acc -> acc + Enum.sum(fs) end)
  end
end
