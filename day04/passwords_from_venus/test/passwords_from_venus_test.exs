defmodule PasswordsFromVenusTest do
  use ExUnit.Case
  doctest PasswordsFromVenus

  setup do
    candidate_password_range = "271973-785961"

    [password_range: candidate_password_range]
  end

  test "personal input processed correctly", context do
    assert PasswordsFromVenus.count_conformant_passwords_in_range(context[:password_range]) == 925
  end
end
