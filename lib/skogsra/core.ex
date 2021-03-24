defmodule Skogsra.Core do
  @moduledoc """
  This module defines the core API for Skogsra.
  """
  alias Skogsra.Binding
  alias Skogsra.Cache
  alias Skogsra.Env

  ############
  # Public API

  @doc """
  Gets the value of a given `env`.
  """
  @spec get_env(Env.t()) :: {:ok, term()} | {:error, binary()}
  def get_env(env)

  def get_env(%Env{} = env) do
    if Env.cached?(env) do
      get_cached(env)
    else
      fsm_entry(env)
    end
  end

  @doc """
  Gets the value of a given `env`. Fails on error.
  """
  @spec get_env!(Env.t()) :: term() | no_return()
  def get_env!(env)

  def get_env!(%Env{} = env) do
    case get_env(env) do
      {:ok, value} ->
        value

      {:error, reason} ->
        raise reason
    end
  end

  @doc """
  Puts a new value for an `env`.
  """
  @spec put_env(Env.t(), term()) :: :ok | {:error, binary()}
  def put_env(env, value)

  def put_env(%Env{} = env, value) do
    if Env.cached?(env) do
      Cache.put_env(env, value)
    else
      {:error, "Cache disable for this variable"}
    end
  end

  @doc """
  Reloads an `env` variable.
  """
  @spec reload_env(Env.t()) :: {:ok, term()} | {:error, binary()}
  def reload_env(env)

  def reload_env(%Env{} = env) do
    case fsm_entry(env) do
      {:ok, value} ->
        if Env.cached?(env), do: Cache.put_env(env, value)
        {:ok, value}

      _ ->
        {:error, "Cannot reload the variable. Keeping last value."}
    end
  end

  #########
  # Helpers

  @doc false
  @spec fsm_entry(Env.t()) :: {:ok, term()} | {:error, binary()}
  def fsm_entry(env)

  def fsm_entry(%Env{} = env) do
    order = Env.binding_order(env)
    default = get_default(env)

    Enum.reduce_while(order, default, fn binding, default ->
      case Binding.get_env(binding, env) do
        nil ->
          {:cont, default}

        value ->
          {:halt, {:ok, value}}
      end
    end)
  end

  @doc false
  @spec get_cached(Env.t()) :: {:ok, term()} | {:error, binary()}
  def get_cached(env)

  def get_cached(%Env{} = env) do
    with :error <- Cache.get_env(env),
         {:ok, value} <- fsm_entry(env),
         :ok <- Cache.put_env(env, value) do
      {:ok, value}
    end
  end

  @doc false
  @spec get_default(Env.t()) :: {:ok, term()} | {:error, binary()}
  def get_default(env)

  def get_default(%Env{namespace: nil} = env) do
    case {Env.default(env), Env.required?(env)} do
      {nil, true} ->
        {:error, format_missing_var_error(env)}

      {value, _} ->
        {:ok, value}
    end
  end

  def get_default(%Env{} = env) do
    get_env(%Env{env | namespace: nil})
  end

  @spec format_missing_var_error(Env.t()) :: binary()
  defp format_missing_var_error(env)

  defp format_missing_var_error(%Env{keys: [key]} = env) do
    """
    Variable for key `#{key}` is undefined for application `#{env.app_name}`:

    - Namespace: #{env.namespace}
    - Module: #{Macro.to_string(env.module)}
    - Function: #{env.function}
    """
  end

  defp format_missing_var_error(%Env{keys: [_ | _] = keys} = env) do
    keys =
      keys
      |> Stream.map(&"`#{&1}`")
      |> Enum.join(", ")

    """
    Variable for keys #{keys} are undefined for application `#{env.app_name}`:

    - Namespace: #{env.namespace}
    - Module: #{Macro.to_string(env.module)}
    - Function: #{env.function}
    """
  end
end
