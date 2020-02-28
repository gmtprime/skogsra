defmodule Skogsra.Binding do
  @moduledoc """
  Variable binding behaviour.
  """

  alias Skogsra.Env
  alias Skogsra.Type

  require Logger

  @doc """
  Callback for initializing binding.
  """
  @callback init(env :: Env.t()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Callback for getting an environment variable.
  """
  @callback get_env(env :: Env.t(), config :: term()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Uses the `Skogsra.Binding` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Skogsra.Binding

      @impl Skogsra.Binding
      def init(_env) do
        {:ok, nil}
      end

      defoverridable init: 1
    end
  end

  @spec get_env(Env.binding(), env :: Env.t()) :: term()
  def get_env(:system, %Env{} = env), do: get_env(Skogsra.Sys, env)
  def get_env(:config, %Env{} = env), do: get_env(Skogsra.App, env)

  def get_env(module, %Env{} = env) do
    with {:ok, config} <- module.init(env),
         {:ok, value} <- module.get_env(env, config) do
      cast(module, env, value)
    else
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
