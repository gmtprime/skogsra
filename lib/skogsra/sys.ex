defmodule Skogsra.Sys do
  @moduledoc """
  This module defines the functions to get environment variables from the OS.
  """
  alias Skogsra.Env
  alias Skogsra.Type

  require Logger

  ############
  # Public API

  @doc """
  Gets a OS environment variable value given a `Skogsra.Env` struct.
  """
  @spec get_env(Env.t()) :: term()
  def get_env(env)

  def get_env(%Env{} = env) do
    if Env.skip_system?(env) do
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

  def do_get_env(%Env{} = env) do
    module = Application.get_env(:skogsra, :system_module, System)
    name = Env.os_env(env)
    value = apply(module, :get_env, [name])

    case Type.cast(env, value) do
      {:ok, value} -> value
      :error -> fail_cast(name, value)
    end
  end

  @doc false
  @spec fail_cast(binary(), term()) :: nil
  def fail_cast(name, value)

  def fail_cast(name, value) do
    Logger.warn("OS variable #{name} cannot be casted from #{inspect(value)}")

    nil
  end
end
