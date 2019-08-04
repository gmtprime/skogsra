defmodule Skogsra.App do
  @moduledoc """
  This module defines the functions to get variables from the configuration.
  """
  alias Skogsra.Env

  ############
  # Public API

  @doc """
  Gets config variable value given a `Skogsra.Env` struct.
  """
  @spec get_env(Env.t()) :: nil | term()
  def get_env(env)

  def get_env(%Env{options: options} = env) do
    if options[:skip_config], do: nil, else: do_get_env(env)
  end

  #########
  # Helpers

  @doc false
  @spec do_get_env(Env.t()) :: nil | term()
  def do_get_env(env)

  def do_get_env(%Env{
        namespace: nil,
        app_name: app_name,
        keys: [key | keys]
      }) do
    module = Application.get_env(:skogsra, :application_module, Application)
    value = apply(module, :get_env, [app_name, key])
    lookup(value, keys)
  end

  def do_get_env(%Env{
        namespace: namespace,
        app_name: app_name,
        keys: keys
      }) do
    module = Application.get_env(:skogsra, :application_module, Application)
    value = apply(module, :get_env, [app_name, namespace])
    lookup(value, keys)
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
end
