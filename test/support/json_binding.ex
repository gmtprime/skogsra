defmodule Skogsra.JsonBinding do
  @moduledoc false
  use Skogsra.Binding

  alias Skogsra.Env

  @impl true
  def init(%Env{} = env) do
    options = Env.extra_options(env)

    case options[:config_path] do
      nil ->
        {:error, "JSON config path not specified"}

      path ->
        load(path)
    end
  end

  @impl true
  def get_env(%Env{} = env, config) do
    name = Env.os_env(env)
    value = config[name]

    {:ok, value}
  end

  # Helpers

  @spec load(binary()) :: {:ok, map()} | {:error, term()}
  defp load(path) do
    with nil <- :persistent_term.get(path, nil),
         {:ok, contents} <- File.read(path),
         {:ok, config} <- Jason.decode(contents),
         :ok <- :persistent_term.put(path, config) do
      {:ok, config}
    else
      {:error, reason} ->
        {:error, "Cannot load #{path} due to #{inspect(reason)}"}

      config ->
        {:ok, config}
    end
  end
end
