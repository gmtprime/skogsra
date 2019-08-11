defmodule Skogsra.App do
  @moduledoc """
  This module defines the functions to get variables from the configuration.
  """
  require Logger

  alias Skogsra.Env
  alias Skogsra.Type

  ############
  # Public API

  @doc """
  Gets config variable value given a `Skogsra.Env` struct.
  """
  @spec get_env(Env.t()) :: term()
  def get_env(env)

  def get_env(%Env{} = env) do
    if Env.skip_config?(env) do
      nil
    else
      do_get_env(env)
    end
  end

  #########
  # Helpers

  @doc false
  @spec do_get_env(Env.t()) :: term()
  def do_get_env(env)

  def do_get_env(
        %Env{namespace: nil, app_name: app_name, keys: [key | keys]} = env
      ) do
    :skogsra
    |> Application.get_env(:application_module, Application)
    |> apply(:get_env, [app_name, key])
    |> lookup(keys)
    |> cast(env)
  end

  def do_get_env(
        %Env{namespace: namespace, app_name: app_name, keys: keys} = env
      ) do
    :skogsra
    |> Application.get_env(:application_module, Application)
    |> apply(:get_env, [app_name, namespace])
    |> lookup(keys)
    |> cast(env)
  end

  @doc false
  @spec lookup(term(), Env.keys()) :: nil | term()
  def lookup(value, keys)

  def lookup(value, []) do
    value
  end

  def lookup(value, [key | keys]) when is_list(value) do
    value
    |> Keyword.get(key)
    |> lookup(keys)
  end

  def lookup(_, _) do
    nil
  end

  @doc false
  def cast(value, %Env{} = env) do
    case Type.cast(env, value) do
      {:ok, value} -> value
      :error -> fail_cast(value, env)
    end
  end

  @doc false
  @spec fail_cast(term(), Env.t()) :: nil
  def fail_cast(value, env)

  def fail_cast(value, %Env{} = env) do
    Logger.warn(
      "Application variable #{inspect(env)} cannot be " <>
        "casted from #{inspect(value)}"
    )

    nil
  end
end
