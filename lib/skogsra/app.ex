defmodule Skogsra.App do
  @moduledoc """
  This module defines the functions to get variables from the application
  configuration.
  """
  use Skogsra.Binding

  alias Skogsra.Env

  ##########
  # Callback

  @impl Skogsra.Binding
  def get_env(env)

  def get_env(%Env{} = env) do
    value = do_get_env(env)

    {:ok, value}
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
end
