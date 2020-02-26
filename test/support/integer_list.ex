defmodule Skogsra.IntegerList do
  @moduledoc false
  use Skogsra.Type

  @impl Skogsra.Type
  def cast(value)

  def cast(value) when is_binary(value) do
    list =
      value
      |> String.split(~r/,/)
      |> Stream.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)

    {:ok, list}
  end

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_integer/1), do: {:ok, value}, else: :error
  end

  def cast(_) do
    :error
  end
end
