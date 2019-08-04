defmodule Skogsra.Cache do
  @moduledoc """
  This module defines the helpers for the variable cache. The cache works with
  persistent terms.
  """
  alias Skogsra.Env

  ############
  # Public API

  @doc """
  Gets a variable value `env` from the cache.
  """
  @spec get_env(Env.t()) :: {:ok, term()} | :error
  def get_env(env)

  def get_env(%Env{} = env) do
    key = gen_key(env)

    case :persistent_term.get(key, nil) do
      nil -> :error
      value -> {:ok, value}
    end
  end

  @doc """
  Stores a variable `env` in a persistent term.
  """
  @spec put_env(Env.t(), term()) :: :ok
  def put_env(env, value)

  def put_env(%Env{} = env, value) do
    key = gen_key(env)
    :persistent_term.put(key, value)
  end

  #########
  # Helpers

  @doc false
  @spec gen_key(Env.t()) :: integer()
  def gen_key(env)

  def gen_key(%Env{} = env) do
    :erlang.phash2(env)
  end
end
