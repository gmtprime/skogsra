if Code.ensure_loaded?(Config.Provider) and Code.ensure_loaded?(:yamerl) do
  defmodule Skogsra.Provider.Yaml do
    @moduledoc """
    This module defines a YAML config provider for Skogsra.

    > **Important**: You need to add `{:yamerl, "~> 0.7"}` as a dependency
    > along with `Skogsra` because the dependency is optional.

    The following is an example for `Ecto` configuration:

    ```yaml
    # file: /etc/my_app/config.yml
    - app: "my_app"
      module: "MyApp.Repo"
      config:
        database: "my_app_db"
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
           {:ok, parsed} <- parse(contents),
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

    @spec parse(binary()) :: {:ok, list()} | {:error, term()}
    defp parse(contents)

    defp parse(contents) when is_binary(contents) do
      [yml] = :yamerl.decode(contents)

      {:ok, yml}
    rescue
      _ ->
        {:error, "Cannot parse configuration YAML file"}
    end

    # Loads a YAML config from a binary.
    @spec load_config(list()) :: {:ok, keyword()} | {:error, term()}
    @spec load_config(list(), list()) :: {:ok, keyword()} | {:error, term()}
    defp load_config(yml, acc \\ [])

    defp load_config([], acc) do
      config =
        acc
        |> List.flatten()
        |> merge_duplicates()

      {:ok, config}
    end

    defp load_config([yml | rest], acc) do
      with {:ok, config} <- load_app_config(yml) do
        load_config(rest, [config | acc])
      end
    end

    @spec merge_duplicates(keyword()) :: keyword()
    defp merge_duplicates(config)

    defp merge_duplicates(config) when is_list(config) do
      config
      |> Enum.reduce(%{}, &do_merge_duplicates/2)
      |> Enum.to_list()
    end

    @spec do_merge_duplicates({atom(), term()}, map()) :: map()
    defp do_merge_duplicates(pair, acc)

    defp do_merge_duplicates({key, [{_, _} | _] = value}, acc) do
      Map.update(acc, key, value, fn
        [{_, _} | _] = existing -> merge_duplicates(existing ++ value)
        _existing -> merge_duplicates(value)
      end)
    end

    defp do_merge_duplicates({key, value}, acc) do
      Map.put(acc, key, value)
    end

    # Loads an app config from a YAML parsed document.
    @spec load_app_config(list()) :: {:ok, keyword()} | {:error, term()}
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
      case get_key(nodes, 'namespace') do
        nil ->
          {:ok, nil}

        value ->
          value =
            value
            |> List.to_string()
            |> String.split(~r/\./)
            |> Module.concat()

          {:ok, value}
      end
    rescue
      _ ->
        {:error, "Namespace is invalid"}
    end

    # Gets module to be configured.
    @spec get_module(list()) :: {:ok, module()} | {:error, term()}
    defp get_module(nodes) do
      case get_key(nodes, 'module') do
        nil ->
          {:ok, nil}

        value ->
          value =
            value
            |> List.to_string()
            |> String.split(~r/\./)
            |> Module.safe_concat()

          {:ok, value}
      end
    rescue
      _ ->
        {:error, "Module is invalid"}
    end

    # Gets config key for an app.
    @spec get_config(list()) :: {:ok, keyword()} | {:error, term()}
    defp get_config(nodes) do
      value =
        nodes
        |> get_key!('config')
        |> Enum.map(&expand_variable/1)
        |> List.flatten()

      {:ok, value}
    rescue
      _ ->
        {:error, "Config is invalid"}
    end

    # Expands a variable
    @spec expand_variable({key(), term()}) :: {atom(), term()}
    defp expand_variable({key, value}) do
      key = to_atom(key)
      value = expand_value(value)

      {key, value}
    end

    # Expand a value
    @spec expand_value(term()) :: term()
    defp expand_value([char | _] = value) when is_integer(char) do
      "#{value}"
    end

    defp expand_value(values) when is_list(values) do
      values
      |> Enum.map(&expand_variable/1)
      |> List.flatten()
    end

    defp expand_value(value) do
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
