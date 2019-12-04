defmodule PasswordsFromVenus do
  @moduledoc """
  count number of passwords in input that meet certain constraints:
  * six-digit number;
  * two adjacent digits are the same (like 22 in 122345);
  * going from left to right, digits never decrease, i.e. only ever increase or stay same (like 111123 or 135679).
  """

  @doc """
  iex> PasswordsFromVenus.count_conformant_passwords_in_range("111111-111111")
  {1, ["111111"]}

  iex> PasswordsFromVenus.count_conformant_passwords_in_range("223450-223450")
  {0, []}

  iex> PasswordsFromVenus.count_conformant_passwords_in_range("123789-123789")
  {0, []}
  """
  @spec count_conformant_passwords_in_range(String.t()) :: tuple
  def count_conformant_passwords_in_range(range_s) do
    [lo, hi] =
      range_s
      |> String.split("-")
      |> Enum.map(&String.to_integer/1)

    # six-digit format inherent in puzzle range input
    # String.match?(w, ~r/^[0123456789]{6,6}$/x) && ...
    conformant_passwords =
      Range.new(lo, hi)
      |> Enum.map(&Integer.to_string/1)
      |> Enum.filter(fn w -> String.match?(w, ~r<(.)\1>) && monotonically_increasing_digits(w) end)

    {length(conformant_passwords), conformant_passwords}
  end

  @doc """
  iex> PasswordsFromVenus.count_strictly_conformant_passwords_in_range("112233-112233")
  {1, ["112233"]}

  iex> PasswordsFromVenus.count_strictly_conformant_passwords_in_range("123444-123444")
  {0, []}

  iex> PasswordsFromVenus.count_strictly_conformant_passwords_in_range("111122-111122")
  {1, ["111122"]}
  """
  @spec count_strictly_conformant_passwords_in_range(String.t()) :: tuple
  def count_strictly_conformant_passwords_in_range(range_s) do
    {_, minimally_conformant_passwords} =
      count_conformant_passwords_in_range(range_s)

    strictly_conformant_passwords =
      minimally_conformant_passwords
      |> Enum.filter(fn w -> strictly_conforming?(w) end)

    {length(strictly_conformant_passwords), strictly_conformant_passwords}
  end

  @spec strictly_conforming?(String.t()) :: boolean
  defp strictly_conforming?(w) do
    Regex.scan(~r/(.)\1/, w)
    |> List.flatten()
    |> Enum.filter(fn s -> String.length(s) == 2 end)
    |> Enum.any?(fn s -> c = String.at(s, 0); !String.match?(w, ~r/#{c}{3,}/x) end)
  end

  @spec monotonically_increasing_digits(String.t()) :: boolean
  defp monotonically_increasing_digits(w) do
    {result, _} =
      w
      |> String.split(~r//)
      |> Enum.filter(fn w -> String.length(w) > 0 end)
      |> Enum.map(&String.to_integer/1)
      |> Enum.reduce(
        {true, 0},
        fn d, {valid, max_digit}->
          if valid && max_digit <= d, do: {valid, d}, else: {false, max_digit}
        end
      )

    result
  end
end
