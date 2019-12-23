defmodule Hackish do
  @val 12

  def main() do
    0..(@val - 1)
    |> Enum.map(fn i -> 2*i end)
    |> IO.inspect()
  end

end

Hackish.main()
