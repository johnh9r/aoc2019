defmodule OxygenSupply.WorldAffairs do
  @moduledoc """
  """

  @type tiles_t :: %{required({integer, integer}) => {String.t(), integer}}

  @wall "#"
  @surface "."
  @oxygen_supply "*"
  @unknown " "

  @move_north 1
  @move_south 2
  @move_west 3
  @move_east 4

  @status_blocked 0
  @status_moved 1
  @status_found 2

  @spec initialize(Keyword.t()) :: pid
  def initialize(initial_state) do
    # https://hexdocs.pm/elixir/Enum.html#random/1
    :rand.seed(:exsplus, {7, 29, 144})
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @spec get_final_state() :: Keyword.t()
  def get_final_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  # XXX random walk?
  @spec handle_input_request() :: {integer}
  def handle_input_request() do
    # TODO consider only smart moves based on known environment (if any) on map
    _state = Agent.get(__MODULE__, fn state -> state end)
    possible_moves = [@move_north, @move_south, @move_west, @move_east]
    chosen_move =
      Enum.random(possible_moves)
      |> IO.inspect(label: "\nheading")

    # XXX closure over last_move
    Agent.update(__MODULE__, fn state -> Keyword.merge(state, [last_move: chosen_move]) end)

    chosen_move
  end

  @spec handle_output_request(integer) :: :ok
  def handle_output_request(value) do
    Agent.update(
      __MODULE__,
      fn state ->
        tiles = Keyword.fetch!(state, :tiles)
        x = Keyword.fetch!(state, :x)
        y = Keyword.fetch!(state, :y)
        last_move = Keyword.fetch!(state, :last_move)
        {_, curr_dist} = Map.get(tiles, {x,y}) 
        {{target_x, target_y}, {target_tile, best_known_target_dist}} = target_tile(tiles, x, y, last_move)

        update =
          case value do
            @status_blocked ->
              IO.inspect({{target_x, target_y}, {target_tile, best_known_target_dist}}, label: "\nblocked")
              # blindly record wall (again);
              # not meaningfully reachable in any number steps;
              # don't move
              new_tiles = Map.put(tiles, {target_x, target_y}, {@wall, nil})
              [tiles: new_tiles, last_move: nil]

            @status_moved ->
              IO.inspect({{target_x, target_y}, {target_tile, best_known_target_dist}}, label: "\nmoved")
              new_tiles =
                case {target_tile, best_known_target_dist} do
                  {nil, _} -> 
                    Map.put(tiles, {target_x, target_y}, {@surface, curr_dist + 1})
                  {@surface, known_target_distance} when curr_dist + 1 < known_target_distance ->
                    Map.put(tiles, {target_x, target_y}, {@surface, curr_dist + 1})
                  {@surface, _} ->
                    # already known as surface with same or shorter distance
                    tiles
                  _ -> raise "unexpected state of map tiles"
                end
              [tiles: new_tiles, x: target_x, y: target_y, last_move: nil]

            @status_found ->
              IO.inspect({{target_x, target_y}, {target_tile, best_known_target_dist}}, label: "\nfound")
              # cannot have encountered terminating condition previously
              # XXX "minimal" distance possibily pathologically longer than direct chance discovery
              new_tiles =
                Map.put(tiles, {target_x, target_y}, {@oxygen_supply, curr_dist + 1})

              # TODO terminate IntCode process cleanly
              IO.inspect("\nfound oxygen supply at {#{target_x}, #{target_y}} in #{curr_dist + 1} steps")
              # TODO  render map (cf Day 13)
              [tiles: new_tiles, x: target_x, y: target_y, last_move: nil]
          end

          Keyword.fetch!(update, :tiles)
          |> render_patchy_map()
          |> (fn screen -> ["\n\n" | screen] end).()
          |> IO.write()

          Keyword.merge(state, update)
      end
    )
  end

  @spec target_tile(tiles_t, integer, integer, integer) :: {{integer, integer}, {String.t(), integer}}
  def target_tile(tiles, x, y, move) do
    {target_x, target_y} =
      case move do
        @move_north -> {x, y + 1}
        @move_south -> {x, y - 1}
        @move_west -> {x - 1, y}
        @move_east -> {x + 1, y}
      end

    {
      {target_x, target_y},
      Map.get(tiles, {target_x, target_y}, {nil, nil})
    }
  end

  @spec render_patchy_map(tiles_t) :: iodata
  defp render_patchy_map(tiles) do
    {
      {{min_x, _this_y}, {_, _}},
      {{max_x, _that_y}, {_, _}}
    }  =
      tiles
      |> Enum.min_max_by(fn {{x,_y}, {_, _}} -> x end)

    {
      {{_this_x, min_y}, {_, _}},
      {{_that_x, max_y}, {_, _}}
    }  =
      tiles
      |> Enum.min_max_by(fn {{_x,y}, {_, _}} -> y end)

    rectangular_background =
      for y <- min_y..max_y, x <- min_x..max_x do
        {{x, y}, {@unknown, nil}}
      end
      |> Enum.into(%{})

    rectangular_background
    |> Map.merge(tiles)
    # use y-coordinate as dominant sort key in order to form scan lines
    |> Enum.group_by(fn {{_x, y}, _tile_id} -> y end)
    |> Enum.into(
      [],
      fn {_group_key_y, tiles} ->
        tiles
        |> Enum.sort_by(fn {{x, _y},_} -> x end)
        |> Enum.map(fn {{_x,_y}, {tile_ch, _}} -> tile_ch end)
      end
    )
    |> Enum.intersperse("\n")
  end

  # auxiliary functions to share constants
  def surface, do: @surface
end

defmodule OxygenSupply do
  @moduledoc """
  use remotely operated repair droid to detect oxygen supply on mystery map

  ## notes
  * coordinate system w/ (x, y) = (0, 0) = starting position
      * coordinates growing negative/positive on both axes
  """

  alias OxygenSupply.WorldAffairs

  @doc """
  """
  @spec calc_min_steps_to_oxygen_supply([integer]) :: integer
  def calc_min_steps_to_oxygen_supply(firmware) do
    {:ok, _pid} = WorldAffairs.initialize(
      tiles: %{
        # starting (by def) at pos {0,0}, which cannot be wall and is zero steps away
        {0,0} => {WorldAffairs.surface, 0}
      },
      x: 0,
      y: 0,
      last_move: nil
    )

    run_robot(firmware)

    state = WorldAffairs.get_final_state()
    Keyword.fetch!(state, :tiles)

  end

  @spec run_robot([integer]) :: :ok
  defp run_robot(firmware) do
    task = Task.async(
      IntCodeBoost,
      :execute,
      [
        firmware,
        # both (in/out) from perspective of IntCode machine
        &WorldAffairs.handle_input_request/0,
        &WorldAffairs.handle_output_request/1
      ]
    )

    Task.await(task, :infinity)
    :ok
  end
end
