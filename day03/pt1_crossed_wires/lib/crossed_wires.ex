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
  # XXX fix naming
  @spec nearest_intersection(String.t(), String.t()) :: integer
  def nearest_intersection(wire1, wire2) do
    {crossing_points, _, _} = intersections(wire1, wire2)

    crossing_points
    |> Enum.min_by(fn {x, y} -> abs(x) + abs(y) end)
    |> (fn {x, y} -> abs(x) + abs(y) end).()
  end

  @doc """
  iex> CrossedWires.nearest_intersection_by_path_length_sum("R8,U5,L5,D3", "U7,R6,D4,L4")
  30

  iex> CrossedWires.nearest_intersection_by_path_length_sum("R75,D30,R83,U83,L12,D49,R71,U7,L72", "U62,R66,U55,R34,D71,R55,D58,R83")
  610

  iex> CrossedWires.nearest_intersection_by_path_length_sum("R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51", "U98,R91,D20,R16,D67,R40,U7,R15,U6,R7")
  410
  """
  @spec nearest_intersection_by_path_length_sum(String.t(), String.t()) :: integer
  def nearest_intersection_by_path_length_sum(wire1, wire2) do
    {crossing_points, coord_set_steps_wire1, coord_set_steps_wire2} = intersections(wire1, wire2)

    {nearest_x, nearest_y} =
      crossing_points
      |> Enum.min_by(
        fn {x, y} ->
          {_, _, steps1} = coord_set_steps_wire1 |> Enum.find(fn {x1, y1, _} -> x == x1 && y == y1 end)
          {_, _, steps2} = coord_set_steps_wire2 |> Enum.find(fn {x2, y2, _} -> x == x2 && y == y2 end)
          steps1 + steps2
        end
      )

    {_, _, steps1} = coord_set_steps_wire1 |> Enum.find(fn {x1, y1, _} -> nearest_x == x1 && nearest_y == y1 end)
    {_, _, steps2} = coord_set_steps_wire2 |> Enum.find(fn {x2, y2, _} -> nearest_x == x2 && nearest_y == y2 end)

    steps1 + steps2
  end

  @spec intersections(String.t(), String.t()) :: tuple
  defp intersections(wire1, wire2) do
    {coord_set_steps_wire1, {_, _}, _} = coord_set_for_rle(wire1)
    {coord_set_steps_wire2, {_, _}, _} = coord_set_for_rle(wire2)

    coord_set_wire1 =
      coord_set_steps_wire1
      |> Enum.into(MapSet.new(), fn {x, y, _} -> {x, y} end)

    coord_set_wire2 =
      coord_set_steps_wire2
      |> Enum.into(MapSet.new(), fn {x, y, _} -> {x, y} end)

    crossing_points =
      MapSet.intersection(coord_set_wire1, coord_set_wire2)
      |> MapSet.delete({0, 0})

    {crossing_points, coord_set_steps_wire1, coord_set_steps_wire2}
  end

  @spec coord_set_for_rle(String.t()) :: MapSet.t()
  defp coord_set_for_rle(rle_from_origin) do
    rle_from_origin
    |> String.split(~r<,>)
    |> Enum.reduce(
      {MapSet.new(), {0, 0}, 0},
      fn rle_segment, acc_pos_coords ->
        {coord_set, {curr_x, curr_y}, steps} = acc_pos_coords
        {direction, count_s} = rle_segment |> String.split_at(1)
        count = String.to_integer(count_s)

        case direction do
          "R" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_x, curr_x + count)
              |> Enum.reduce(coord_set, fn x, acc -> MapSet.put(acc, {x, curr_y, steps + abs(abs(x) - abs(curr_x))}) end)

            {coord_set_plus_polyline_segment, {curr_x + count, curr_y}, steps + count}

          "L" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_x - count, curr_x)
              |> Enum.reduce(coord_set, fn x, acc -> MapSet.put(acc, {x, curr_y, steps + abs(abs(x) - abs(curr_x))}) end)

            {coord_set_plus_polyline_segment, {curr_x - count, curr_y}, steps + count}

          "U" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_y, curr_y + count)
              |> Enum.reduce(coord_set, fn y, acc -> MapSet.put(acc, {curr_x, y, steps + abs(abs(y) - abs(curr_y))}) end)

            {coord_set_plus_polyline_segment, {curr_x, curr_y + count}, steps + count}

          "D" ->
            coord_set_plus_polyline_segment =
              Range.new(curr_y - count, curr_y)
              |> Enum.reduce(coord_set, fn y, acc -> MapSet.put(acc, {curr_x, y, steps + abs(abs(y) - abs(curr_y))}) end)

            {coord_set_plus_polyline_segment, {curr_x, curr_y - count}, steps + count}

          _ ->
            1 / 0
        end
      end
    )
  end
end
