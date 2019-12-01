defmodule FuelCounter do
  @moduledoc """
  calculate sum of units of fuel required to launch collection of modules with given masses
  """

  @doc """
  ## [Examples](https://adventofcode.com/2019/day/1)

  iex> FuelCounter.fuel_for_mass(12)
  2
  iex> FuelCounter.fuel_for_mass(14)
  2
  iex> FuelCounter.fuel_for_mass(1969)
  654
  iex> FuelCounter.fuel_for_mass(100_756)
  33_583
  """
  @spec fuel_for_mass(integer) :: integer
  def fuel_for_mass(m) do
    div(m, 3) - 2
  end

  @doc """
  iex> FuelCounter.total_fuel([12, 14, 1969, 100_756])
  34_241
  """
  @spec total_fuel([integer]) :: integer
  def total_fuel(ms) do
    Enum.reduce(ms, 0, fn m, acc -> acc + fuel_for_mass(m) end)
  end
end
