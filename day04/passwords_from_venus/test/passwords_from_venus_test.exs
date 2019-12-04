defmodule PasswordsFromVenusTest do
  use ExUnit.Case
  doctest PasswordsFromVenus

  setup do
    candidate_password_range = "271973-785961"

    [password_range: candidate_password_range]
  end

  test "(part 1) personal input processed correctly", context do
    {n, ws} = PasswordsFromVenus.count_conformant_passwords_in_range(context[:password_range])
    assert {n, ws |> Enum.take(5)} ==  {925, ["277777", "277778", "277779", "277788", "277789"]}
  end

  test "(part 2) personal input processed correctly", context do
    {n, ws} = PasswordsFromVenus.count_strictly_conformant_passwords_in_range(context[:password_range])
    assert {n, ws |> Enum.take(5)} ==  {607, ["277788", "277799", "277888", "277889", "277899"]}
  end
end
