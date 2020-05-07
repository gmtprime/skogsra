defmodule Skogsra.App do
  @moduledoc """
  This module defines the functions to get variables from the application
  configuration.
  """
  use Skogsra.Binding

  alias Skogsra.Core
  alias Skogsra.Env

  ##########
  # Callback

  @impl Skogsra.Binding
  def get_env(env, config)

  def get_env(%Env{} = env, _config) do
    value = do_get_env(env)

    {:ok, value}
  end

  ############
  # Public API

  @doc """
  Overrides an config value with Skogsra's value.
  """
  @spec preload(Env.t()) :: :ok
  def preload(env)

  def preload(%Env{app_name: app, namespace: nil, keys: [key | keys]} = env) do
    module = application_module()

    with {:ok, value} when not is_nil(value) <- Core.get_env(env) do
      config = module.get_env(app, key)
      new_config = deep_merge(keys, config, value)
      module.put_env(app, key, new_config)
    end

    :ok
  end

  def preload(%Env{app_name: app, namespace: namespace, keys: keys} = env) do
    module = application_module()

    with {:ok, value} when not is_nil(value) <- Core.get_env(env) do
      config = module.get_env(app, namespace)
      new_config = deep_merge(keys, config, value)
      module.put_env(app, namespace, new_config)
    end

    :ok
  end

  #########
  # Helpers

  @spec do_get_env(Env.t()) :: term()
  defp do_get_env(env)

  defp do_get_env(%Env{namespace: nil, keys: [key | keys]} = env) do
    do_get_env(%Env{env | namespace: key, keys: keys})
  end

  defp do_get_env(%Env{} = env) do
    application_module()
    |> apply(:get_env, [env.app_name, env.namespace])
    |> lookup(env.keys)
  end

  @spec lookup(term(), Env.keys()) :: nil | term()
  defp lookup(value, keys)

  defp lookup(value, []) do
    value
  end

  defp lookup(value, [key | keys]) when is_list(value) do
    value
    |> Keyword.get(key)
    |> lookup(keys)
  end

  defp lookup(_, _) do
    nil
  end

  @spec application_module() :: module()
  defp application_module do
    Application.get_env(:skogsra, :application_module, Application)
  end

  @spec deep_merge([atom()], term(), term()) :: keyword() | term()
  defp deep_merge([], _, value), do: value

  defp deep_merge([key | keys], config, value) do
    if Keyword.keyword?(config) do
      inner = Keyword.get(config, key, [])
      Keyword.put(config, key, deep_merge(keys, inner, value))
    else
      Keyword.put([], key, deep_merge(keys, [], value))
    end
  end
end
