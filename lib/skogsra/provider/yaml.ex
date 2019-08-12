if Code.ensure_loaded?(:yamerl) do
  defmodule Skogsra.Provider.Yaml do
    @moduledoc """
    This module defines a YAML config provider for Skogsra.

    > **Important**: You need to add `{:yamerl, "~> 0.7"}` as a dependency
    > along with `Skogsra` because the dependency is optional.

    The following is an example for `Ecto` configuration:

    ```yaml
    # file: /etc/my_app/config.yml
    - app: "my_app"
      namespace: "MyApp.Repo"
      config:
      - database: "my_app_db"
        username: "postgres"
        password: "postgres"
        hostname: "localhost"
        port: 5432
    ```

    Then in your release configuration you can add the following:

    ```elixir
    config_providers: [{Skogsra.Provider.Yaml, ["/etc/my_app/config.yml"]}]
    ```

    Once the system boots, it'll parse and add the YAML configuration.
    """
    @behaviour Config.Provider

    require Logger

    @type key :: [integer()]

    ###########
    # Callbacks

    @impl Config.Provider
    def init(path) when is_binary(path) do
      path
    end

    @impl Config.Provider
    def load(config, path) do
      {:ok, _} = Application.ensure_all_started(:logger)
      {:ok, _} = Application.ensure_all_started(:yamerl)

      with {:ok, contents} <- File.read(path),
           {:ok, new_config} <- load_config(contents) do
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

    # Loads a YAML config from a binary.
    @spec load_config(binary()) :: {:ok, keyword()} | {:error, term()}
    defp load_config(contents) when is_binary(contents) do
      [yml] = :yamerl.decode(contents)

      load_config(yml, [])
    rescue
      _ ->
        {:error, "Cannot parse configuration YAML file"}
    end

    # Loads apps configs from a YAML parsed document.
    @spec load_config(list(), list()) :: {:ok, keyword()} | {:error, term()}
    defp load_config(yml, acc)

    defp load_config([], acc) do
      config =
        acc
        |> Enum.reverse()
        |> List.flatten()

      {:ok, config}
    end

    defp load_config([yml | rest], acc) do
      with {:ok, config} <- load_app_config(yml) do
        load_config(rest, [config | acc])
      end
    end

    # Loads an app config from a YAML parsed document.
    @spec load_app_config(list()) :: {:ok, keyword()} | {:error, term()}
    defp load_app_config(config) do
      with {:ok, app} <- get_app(config),
           {:ok, namespace} <- get_namespace(config),
           {:ok, config} <- get_config(config) do
        if is_nil(namespace) do
          {:ok, [{app, config}]}
        else
          {:ok, [{app, [{namespace, config}]}]}
        end
      end
    end

    # Gets the name of an app.
    @spec get_app(list()) :: {:ok, atom()} | {:error, term()}
    defp get_app(nodes) when is_list(nodes) do
      value =
        nodes
        |> get_key!('app')
        |> to_atom()

      {:ok, value}
    rescue
      _ ->
        {:error, "Name of the app is invalid"}
    end

    # Gets namespace for an app.
    @spec get_namespace(list()) :: {:ok, module()} | {:error, term()}
    defp get_namespace(nodes) do
      with value when not is_nil(value) <- get_key(nodes, 'namespace') do
        value =
          value
          |> List.to_string()
          |> String.split(~r/\./)
          |> Module.concat()

        {:ok, value}
      else
        nil ->
          {:ok, nil}
      end
    rescue
      _ ->
        {:error, "Namespace is invalid"}
    end

    # Gets config key for an app.
    @spec get_config(list()) :: {:ok, keyword()} | {:error, term()}
    defp get_config(nodes) do
      value =
        nodes
        |> get_key!('config')
        |> Enum.map(&transform_config/1)
        |> List.flatten()

      {:ok, value}
    rescue
      _ ->
        {:error, "Config is invalid"}
    end

    # Transforms parsed YAML to a valid config.
    @spec transform_config(list()) :: keyword() | no_return()
    @spec transform_config(list(), keyword()) :: keyword() | no_return()
    defp transform_config(config, acc \\ [])

    defp transform_config([], acc) do
      Enum.reverse(acc)
    end

    defp transform_config([{key, value} | rest], acc) do
      key = to_atom(key)
      value = transform_value(value)
      new_acc = Keyword.put_new(acc, key, value)

      transform_config(rest, new_acc)
    end

    # Transforms a configuration value.
    @spec transform_value(term()) :: term()
    defp transform_value([f | _] = value) when is_integer(f) do
      "#{value}"
    end

    defp transform_value(values) when is_list(values) do
      values
      |> Enum.map(&transform_config/1)
      |> List.flatten()
    end

    defp transform_value(value) do
      value
    end

    # Transforms a char list to atom.
    @spec to_atom(key()) :: atom() | no_return()
    defp to_atom(key) do
      key
      |> List.to_string()
      |> String.to_atom()
    end

    # Gets a key from a node list.
    @spec get_key(list(), key()) :: nil | term()
    defp get_key(nodes, key) do
      with {^key, value} <- Enum.find(nodes, fn {k, _} -> k == key end) do
        value
      end
    end

    # Gets a key from a node list or fails if it's no found.
    @spec get_key!(list(), key()) :: term() | no_return()
    defp get_key!(nodes, key) do
      case get_key(nodes, key) do
        nil -> raise RuntimeError, message: "Key #{key} not found"
        value -> value
      end
    end
  end
end
