defmodule SpaceImageFormat do
  @moduledoc """
  calculate (unusual) checksum for given data in (unusual) Space Image Format (SIF)
  """

  @doc """
  ```
  Layer 1: 123
           456

  Layer 2: 789
           012
  ```
  first layer has fewest zeroes, and 1 one times 1 two is checksum 1

  iex> SpaceImageFormat.calc_sif_checksum("123456789012", 3, 2)
  1
  """
  @spec calc_sif_checksum(String.t(), integer, integer) :: integer
  def calc_sif_checksum(sif_data_s, width, height) do
    sif_data_s
    |> convert()
    |> as_layers(width, height)
    |> pick_checksum_layer()
    |> calc_checksum()
  end

  @doc """
  iex> SpaceImageFormat.convert("123456789012")
  [1,2,3,4,5,6,7,8,9,0,1,2]
  """
  @spec convert(String.t) :: [integer]
  def convert(sif_data_s) do
    sif_data_s
    |> String.split("")
    |> Enum.filter(fn s -> s != "" end)
    |> Enum.map(&String.to_integer/1)
  end

  @doc """
  iex> SpaceImageFormat.as_layers([1,2,3, 4,5,6,  7,8,9, 0,1,2], 3, 2)
  [[1,2,3, 4,5,6], [7,8,9, 0,1,2]]
  """
  # XXX represent each layer as contiguous pixel stream (w/o reflecting 2-d structure)
  @spec as_layers([integer], integer, integer) :: [[integer]]
  def as_layers(sif_data, width, height) do
    layers =
      sif_data
      |> Stream.chunk_every(width * height)
      # XXX force evaluation for doctest
      |> Enum.map(&(&1))
  end

  @doc """
  iex> SpaceImageFormat.pick_checksum_layer([[1,2,3, 4,5,6], [7,8,9, 0,1,2]])
  [1,2,3, 4,5,6]

  iex> SpaceImageFormat.pick_checksum_layer([[1,2,3,4,5,6,7,8,9,0], [0,2,3,4,5,6,7,8,9,0], [0,0,3,4,5,6,7,8,9,0], [0,0,0,4,5,6,7,8,9,0]])
  [1,2,3,4,5,6,7,8,9,0]
  """
  @spec pick_checksum_layer([[integer]]) :: [integer]
  def pick_checksum_layer(layers) do
    layers
    |> Enum.min_by(
      fn layer ->
        [zeroes | _] = derive_histogram(layer)
        zeroes
      end
    )
  end

  @doc """
  iex> SpaceImageFormat.calc_checksum([1,2,3, 4,5,6])
  1

  iex> SpaceImageFormat.calc_checksum([1,2,3,4,5,1,2,2,9,0])
  6
  """
  @spec calc_checksum([integer]) :: integer
  def calc_checksum(layer) do
    histogram = derive_histogram(layer)

    # from problem definition
    [_, ones | _] = histogram
    [_, _, twos | _] = histogram

    ones * twos
  end

  @doc """
  iex> SpaceImageFormat.derive_histogram([1,2,3,4,5,6,7,8,9,0, 0,2,3,4,5,6,7,8,9,0, 0,0,3,4,5,6,7,8,9,0, 0,0,0,4,5,6,7,8,9,0])
  [10, 1, 2, 3, 4, 4, 4, 4, 4, 4]
  """
  @spec derive_histogram([integer]) :: [integer]
  def derive_histogram(layer) do
    bins =
      layer
      |> Enum.reduce(
	%{"0" => 0, "1" => 0, "2" => 0, "3" => 0, "4" => 0, "5" => 0, "6" => 0, "7" => 0, "8" => 0, "9" => 0},
	fn pixel, acc ->
	  Map.update!(acc, Integer.to_string(pixel), fn count -> count + 1 end)
	end
      )
    
    [bins["0"], bins["1"], bins["2"], bins["3"], bins["4"], bins["5"], bins["6"], bins["7"], bins["8"], bins["9"]]
  end
end
