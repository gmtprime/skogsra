defmodule Skogsra.Type do
  @moduledoc """
  This module defines the functions and behaviours for casting `Skogsra` types.
  """
  alias Skogsra.Env

  ############
  # Public API

  @doc """
  Callback for casting a value.
  """
  @callback cast(term()) :: {:ok, term()} | :error

  @doc """
  Uses `Skogsra.Type` for implementing the behaviour e.g. a naive implementation
  for casting `"1, 2, 3, 4"` to `["1", "2", "3", "4"]` would be:

  ```
  defmodule MyList do
    use Skogsra.Type

    def cast(value) when is_binary(value) do
      list =
        value
        |> String.split(~r/,/)
        |> Enum.map(&String.trim/1)
      {:ok, list}
    end

    def cast(_) do
      :error
    end
  end
  ```
  """
  defmacro __using__(_) do
    quote do
      @behaviour Skogsra.Type

      def cast(value) do
        Skogsra.Type.cast_binary(value)
      end

      defoverridable cast: 1
    end
  end

  @doc """
  Casts an environment variable.
  """
  @spec cast(Env.t(), term()) :: {:ok, term()} | :error
  def cast(env, value)

  def cast(_env, nil) do
    {:ok, nil}
  end

  def cast(%Env{} = env, value) do
    type = Env.type(env)

    do_cast(type, value)
  end

  #########
  # Helpers

  @doc false
  @spec do_cast(Env.type(), term()) :: {:ok, term()} | :error
  def do_cast(:binary, value), do: cast_binary(value)
  def do_cast(:integer, value), do: cast_integer(value)
  def do_cast(:float, value), do: cast_float(value)
  def do_cast(:boolean, value), do: cast_boolean(value)
  def do_cast(:atom, value), do: cast_atom(value)
  def do_cast(module, value), do: module.cast(value)

  @doc false
  @spec cast_binary(term()) :: {:ok, binary()} | :error
  def cast_binary(value)

  def cast_binary(value) when is_binary(value) do
    {:ok, value}
  end

  def cast_binary(value) do
    {:ok, to_string(value)}
  rescue
    _ ->
      :error
  end

  @doc false
  @spec cast_integer(term()) :: {:ok, integer()} | :error
  def cast_integer(value) when is_integer(value) do
    {:ok, value}
  end

  def cast_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  def cast_integer(_) do
    :error
  end

  @doc false
  @spec cast_float(term()) :: {:ok, float()} | :error
  def cast_float(value) when is_float(value) do
    {:ok, value}
  end

  def cast_float(value) when is_binary(value) do
    case Float.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  def cast_float(_) do
    :error
  end

  @doc false
  @spec cast_boolean(term()) :: {:ok, boolean()} | :error
  def cast_boolean(value) when is_boolean(value) do
    {:ok, value}
  end

  def cast_boolean(value) when is_binary(value) do
    case String.downcase(value) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> :error
    end
  end

  def cast_boolean(_) do
    :error
  end

  @doc false
  @spec cast_atom(term()) :: {:ok, atom()} | :error
  def cast_atom(value) when is_atom(value) do
    {:ok, value}
  end

  def cast_atom(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    _ ->
      :error
  end

  def cast_atom(_) do
    :error
  end
end
