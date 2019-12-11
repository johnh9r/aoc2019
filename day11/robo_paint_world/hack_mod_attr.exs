defmodule Foo do
  @value 42

  defmodule Bar do
    @eulav 666

    def access_inside_bar(), do: @eulav
    def access_to_foo_from_bar(), do: @Foo.value
  end

  def access_inside_foo(), do: @value
end
