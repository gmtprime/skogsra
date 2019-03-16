defmodule Skogsra.Cache do
  @moduledoc """
  This module defines the helpers for the variable cache.
  """
  alias Skogsra.Env

  ############
  # Public API

  @doc """
  Creates a new cache.
  """
  @spec new() :: :ets.tab()
  def new do
    opts = [:set, :named_table, :public, read_concurrency: true]
    :ets.new(Env.get_cache_name(), opts)
  end

  @doc """
  Gets a variable value `env` from the cache.
  """
  @spec get_env(Env.t()) :: {:ok, term()} | :error
  def get_env(env)

  def get_env(%Env{cache: cache} = env) do
    key = gen_key(env)

    case :ets.lookup(cache, key) do
      [] ->
        :error

      [{^key, value} | _] ->
        {:ok, value}
    end
  end

  @doc """
  Stores a variable `env` in the cache.
  """
  @spec put_env(Env.t(), term()) :: :ok
  def put_env(env, value)

  def put_env(%Env{cache: cache} = env, value) do
    key = gen_key(env)
    :ets.insert(cache, {key, value})
    :ok
  end

  #########
  # Helpers

  @doc false
  def gen_key(%Env{} = env) do
    env
    |> Map.take([:namespace, :app_name, :keys, :options])
    |> :erlang.phash2()
  end
end
