defmodule Hack do
  Orbits.find_path(%{}, :com) |> IO.inspect()
  Orbits.find_path(%{com: []}, :com) |> IO.inspect()
  Orbits.find_path(%{com: [%{b: [%{c: [], g: [%{h: []}]}]}]}) |> IO.inspect()
end
