defmodule Skogsra.Binding do
  @moduledoc """
  Variable binding behaviour.
  """

  alias Skogsra.Env
  alias Skogsra.Type

  require Logger

  @doc """
  Callback for getting an environment variable.
  """
  @callback get_env(env :: Env.t()) :: {:ok, term()} | {:error, term()}

  @doc """
  Uses the `Skogsra.Binding` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Skogsra.Binding
    end
  end

  @spec get_env(Env.binding(), env :: Env.t()) :: term()
  def get_env(:system, %Env{} = env), do: get_env(Skogsra.Sys, env)
  def get_env(:config, %Env{} = env), do: get_env(Skogsra.App, env)

  def get_env(module, %Env{} = env) do
    case module.get_env(env) do
      {:ok, value} ->
        cast(module, env, value)

      {:error, reason} ->
        Logger.warn(reason, module: module, env: env, value: nil)
        nil

      _ ->
        nil
    end
  end

  #########
  # Helpers

  @spec cast(module(), Env.t(), term()) :: nil | term()
  defp cast(module, env, value) do
    case Type.cast(env, value) do
      {:ok, value} ->
        value

      :error ->
        reason =
          "Cannot cast #{inspect(value)} " <>
            " for environment variable #{inspect(env)}"

        Logger.warn(reason, module: module, env: env, value: value)

        nil
    end
  end
end
