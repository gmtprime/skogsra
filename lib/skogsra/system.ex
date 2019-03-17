defmodule Skogsra.System do
  @moduledoc """
  This module defines the functions to get environment variables from the OS.
  """
  alias Skogsra.Env

  require Logger

  ############
  # Public API

  @doc """
  Gets a OS environment variable value given a `Skogsra.Env` struct.
  """
  @spec get_env(Env.t()) :: nil | term()
  def get_env(env)

  def get_env(%Env{options: options} = env) do
    if not options[:skip_system], do: do_get_env(env), else: nil
  end

  #########
  # Helpers

  @doc false
  @spec do_get_env(Env.t()) :: nil | term()
  def do_get_env(env)

  def do_get_env(%Env{} = env) do
    module = Application.get_env(:skogsra, :system_module, System)

    name = gen_env_name(env)
    value = apply(module, :get_env, [name])

    cast(env, name, value)
  end

  @doc false
  @spec gen_env_name(Env.t()) :: binary()
  def gen_env_name(env)

  def gen_env_name(%Env{options: options} = env) do
    case options[:os_env] do
      nil ->
        namespace = gen_namespace(env)
        app_name = gen_app_name(env)
        keys = gen_keys(env)

        "#{namespace}#{app_name}_#{keys}"

      value ->
        value
    end
  end

  @doc false
  @spec gen_app_name(Env.t()) :: binary()
  def gen_app_name(env)

  def gen_app_name(%Env{app_name: app_name}) do
    app_name
    |> Atom.to_string()
    |> String.upcase()
  end

  @doc false
  @spec gen_keys(Env.t()) :: binary()
  def gen_keys(env)

  def gen_keys(%Env{keys: keys}) do
    keys
    |> Stream.map(&Atom.to_string/1)
    |> Stream.map(&String.upcase/1)
    |> Enum.join("_")
  end

  @doc false
  @spec gen_namespace(Env.t()) :: binary()
  def gen_namespace(env)

  def gen_namespace(%Env{namespace: nil}) do
    ""
  end

  def gen_namespace(%Env{namespace: namespace}) do
    value =
      namespace
      |> Module.split()
      |> Stream.map(&String.upcase/1)
      |> Enum.join("_")

    "#{value}_"
  end

  @doc false
  @spec cast(Env.t(), binary(), binary()) :: nil | term()
  def cast(env, name, value)

  def cast(_env, _name, nil) do
    nil
  end

  def cast(%Env{} = env, name, value) do
    type = get_type(env)

    do_cast(type, name, value)
  end

  @doc false
  @spec get_type(Env.t()) :: Env.type()
  def get_type(env)

  def get_type(%Env{options: options}) do
    case options[:type] do
      nil ->
        type?(options[:default]) || :binary

      type ->
        type
    end
  end

  @doc false
  @spec type?(term()) :: nil | Env.type()
  def type?(value)

  def type?(nil), do: nil
  def type?(value) when is_binary(value), do: :binary
  def type?(value) when is_integer(value), do: :integer
  def type?(value) when is_float(value), do: :float
  def type?(value) when is_boolean(value), do: :boolean
  def type?(value) when is_atom(value), do: :atom
  def type?(_), do: nil

  @doc false
  @spec do_cast(Env.type(), binary(), binary()) :: nil | term()
  def do_cast(type, name, value)

  def do_cast(:binary, _name, value) do
    value
  end

  def do_cast(:integer, name, value) do
    case Integer.parse(value) do
      {value, ""} ->
        value

      _ ->
        fail_cast(:integer, name)
    end
  end

  def do_cast(:float, name, value) do
    case Float.parse(value) do
      {value, ""} ->
        value

      _ ->
        fail_cast(:float, name)
    end
  end

  def do_cast(:boolean, name, value) do
    case String.downcase(value) do
      "true" ->
        true

      "false" ->
        false

      _ ->
        fail_cast(:boolean, name)
    end
  end

  def do_cast(:atom, _name, value) do
    String.to_atom(value)
  end

  def do_cast({module, function} = pair, name, value) do
    with {:ok, new_value} <- apply(module, function, [value]) do
      new_value
    else
      {:error, reason} ->
        fail_cast(pair, name, reason)
    end
  end

  @doc false
  @spec fail_cast(Env.type(), binary()) :: nil
  @spec fail_cast(Env.type(), binary(), term()) :: nil
  def fail_cast(type, name, reason \\ nil)

  def fail_cast(type, name, nil) do
    Logger.warn(fn ->
      "OS variable #{name} cannot be casted to #{inspect(type)}"
    end)

    nil
  end

  def fail_cast(type, name, reason) do
    Logger.warn(fn ->
      "OS variable #{name} cannot be casted to #{inspect(type)} " <>
        "due to #{inspect(reason)}"
    end)

    nil
  end
end
