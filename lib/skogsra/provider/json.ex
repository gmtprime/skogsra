if Code.ensure_loaded?(Config.Provider) and Code.ensure_loaded?(Jason) do
  defmodule Skogsra.Provider.Json do
    @moduledoc """
    This module defines a JSON config provider for Skogsra.

    > **Important**: You need to add `{:jason, "~> 1.1"}` as a dependency
    > along with `Skogsra` because the dependency is optional.

    The following is an example for `Ecto` configuration in a file called
    `/etc/my_app/config.yml`:

    ```json
    [
      {
        "app": "my_app",
        "module": "MyApp.Repo",
        "config": {
          "database": "my_app_db",
          "username": "postgres",
          "password": "postgres",
          "hostname": "localhost",
          "port": 5432
        }
      }
    ]
    ```

    Then in your release configuration you can add the following:

    ```elixir
    config_providers: [{Skogsra.Provider.Json, ["/etc/my_app/config.json"]}]
    ```

    Once the system boots, it'll parse and add the JSON configuration.
    """
    @behaviour Config.Provider

    require Logger

    ###########
    # Callbacks

    @impl Config.Provider
    def init(path) when is_binary(path) do
      path
    end

    @impl Config.Provider
    def load(config, path) do
      {:ok, _} = Application.ensure_all_started(:logger)
      {:ok, _} = Application.ensure_all_started(:jason)

      with {:ok, contents} <- File.read(path),
           {:ok, parsed} <- Jason.decode(contents),
           {:ok, new_config} <- load_config(parsed) do
        Config.Reader.merge(config, new_config)
      else
        {:error, reason} ->
          Logger.warn(
            "File #{path} cannot be read/loaded " <>
              "due to #{inspect(reason)}"
          )

          config
      end
    end

    #########
    # Helpers

    # Loads a JSON config from a list of maps.
    @spec load_config([map()]) :: {:ok, keyword()} | {:error, term()}
    @spec load_config([map()], list()) :: {:ok, keyword()} | {:error, term()}
    defp load_config(maps, acc \\ [])

    defp load_config([], acc) do
      config =
        acc
        |> Enum.reverse()
        |> List.flatten()

      {:ok, config}
    end

    defp load_config([json | rest], acc) do
      with {:ok, config} <- load_app_config(json) do
        load_config(rest, [config | acc])
      end
    end

    # Loads an app config from a YAML parsed document.
    @spec load_app_config(map()) :: {:ok, keyword()} | {:error, term()}
    defp load_app_config(config) do
      with {:ok, app} <- get_app(config),
           {:ok, namespace} <- get_namespace(config),
           {:ok, module} <- get_module(config),
           {:ok, app_config} <- get_config(config) do
        module = module || namespace

        if is_nil(module) do
          {:ok, [{app, app_config}]}
        else
          {:ok, [{app, [{module, app_config}]}]}
        end
      end
    end

    # Gets the name of an app.
    @spec get_app(map()) :: {:ok, atom()} | {:error, term()}
    defp get_app(config) when is_map(config) do
      value =
        config
        |> Map.get("app")
        |> String.to_atom()

      {:ok, value}
    rescue
      _ ->
        {:error, "Name of the app is invalid"}
    end

    # Gets namespace for an app.
    @spec get_namespace(map()) :: {:ok, module()} | {:error, term()}
    defp get_namespace(config) do
      case Map.get(config, "namespace") do
        nil ->
          {:ok, nil}

        value ->
          value =
            value
            |> String.split(~r/\./)
            |> Module.concat()

          {:ok, value}
      end
    rescue
      _ ->
        {:error, "Namespace is invalid"}
    end

    # Gets module to be configured.
    @spec get_module(map()) :: {:ok, module()} | {:error, term()}
    defp get_module(config) do
      case Map.get(config, "module") do
        nil ->
          {:ok, nil}

        value ->
          value =
            value
            |> String.split(~r/\./)
            |> Module.safe_concat()

          {:ok, value}
      end
    rescue
      _ ->
        {:error, "Module is invalid"}
    end

    # Gets config key for an app.
    @spec get_config(map()) :: {:ok, keyword()} | {:error, term()}
    defp get_config(config) do
      value =
        config
        |> Map.get("config")
        |> Enum.map(&expand_variable/1)
        |> List.flatten()

      {:ok, value}
    rescue
      _ ->
        {:error, "Config is invalid"}
    end

    # Expands a variable.
    @spec expand_variable({binary(), term()}) :: {atom(), term()}
    defp expand_variable({key, value}) do
      key = String.to_atom(key)
      value = expand_value(value)

      {key, value}
    end

    # Expands a value
    @spec expand_value(term()) :: term()
    defp expand_value(value)

    defp expand_value(values) when is_map(values) do
      values
      |> Enum.map(&expand_variable/1)
      |> List.flatten()
    end

    defp expand_value(value) do
      value
    end
  end
end
