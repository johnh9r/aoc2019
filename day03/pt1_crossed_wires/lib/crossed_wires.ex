defmodule CrossedWires do
  @moduledoc """
  determine nearest crossing point (by Manhattan distance) of two wires on grid;
  both wires given as run-length encodings of their polyline segments;
  each wire processed as set of Cartesian coordinate tuples that it occupies
  """

  @doc """
  iex> CrossedWires.nearest_intersection("R8,U5,L5,D3", "U7,R6,D4,L4")
  6

  iex> CrossedWires.nearest_intersection("R75,D30,R83,U83,L12,D49,R71,U7,L72", "U62,R66,U55,R34,D71,R55,D58,R83")
  159

  iex> CrossedWires.nearest_intersection("R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51", "U98,R91,D20,R16,D67,R40,U7,R15,U6,R7")
  135
  """
  @spec nearest_intersection(String.t(), String.t()) :: tuple
  def nearest_intersection(wire1, wire2) do
    {coord_set_wire1, {_, _}} = coord_set_for_rle(wire1)
    {coord_set_wire2, {_, _}} = coord_set_for_rle(wire2)

    MapSet.intersection(coord_set_wire1, coord_set_wire2)
    |> MapSet.delete({0, 0})
    |> Enum.min_by(fn {x, y} -> abs(x) + abs(y) end)
    |> (fn {x, y} -> abs(x) + abs(y) end).()
  end

  @spec coord_set_for_rle(String.t()) :: MapSet.t()
  defp coord_set_for_rle(rle_from_origin) do
    rle_from_origin
    |> String.split(~r<,>)
    |> Enum.reduce(
      {MapSet.new(), {0, 0}},
      fn rle_segment, acc_pos_coords ->
        {coord_set, {curr_x, curr_y}} = acc_pos_coords
        {direction, count_s} = rle_segment |> String.split_at(1)
        count = String.to_integer(count_s)

        case direction do
          "R" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_x, curr_x + count)
              |> Enum.reduce(coord_set, fn x, acc -> MapSet.put(acc, {x, curr_y}) end)

            {coord_set_plus_polyline_segment, {curr_x + count, curr_y}}

          "L" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_x - count, curr_x)
              |> Enum.reduce(coord_set, fn x, acc -> MapSet.put(acc, {x, curr_y}) end)

            {coord_set_plus_polyline_segment, {curr_x - count, curr_y}}

          "U" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_y, curr_y + count)
              |> Enum.reduce(coord_set, fn y, acc -> MapSet.put(acc, {curr_x, y}) end)

            {coord_set_plus_polyline_segment, {curr_x, curr_y + count}}

          "D" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_y - count, curr_y)
              |> Enum.reduce(coord_set, fn y, acc -> MapSet.put(acc, {curr_x, y}) end)

            {coord_set_plus_polyline_segment, {curr_x, curr_y - count}}

          _ ->
            1 / 0
        end
      end
    )
  end
end
