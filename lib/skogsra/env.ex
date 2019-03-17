defmodule Skogsra.Env do
  @moduledoc """
  This module defines a `Skogsra` environment variable.
  """
  alias __MODULE__

  @cache :skogsra_cache

  @typedoc """
  Variable namespace.
  """
  @type namespace :: nil | atom()

  @typedoc """
  Application name.
  """
  @type app_name :: nil | atom()

  @typedoc """
  Key.
  """
  @type key :: atom()

  @typedoc """
  List of keys that lead to the value of the variable.
  """
  @type keys :: [key()]

  @typedoc """
  Types
  """
  @type type ::
          :binary
          | :integer
          | :float
          | :boolean
          | :atom
          | {module(), atom()}

  @typedoc """
  Environment variable options.
  - `skip_system` - Skips loading the variable from the OS.
  - `skip_config` - Skips loading the variable from the config.
  - `os_env` - The name of the OS environment variable.
  - `type` - Type to cast the OS environment variable value.
  - `namespace` - Default namespace for the variable.
  - `default` - Default value.
  - `required` - Whether the variable is required or not.
  - `cached` - Whether the variable is cached or not.
  """
  @type option ::
          {:skip_system, boolean()}
          | {:skip_config, boolean()}
          | {:os_env, binary()}
          | {:type, type()}
          | {:namespace, namespace()}
          | {:default, term()}
          | {:required, boolean()}
          | {:cached, boolean()}

  @typedoc """
  Environment variable options:
  """
  @type options :: [option()]

  @doc """
  Environment variable struct.
  """
  defstruct cache: @cache,
            namespace: nil,
            app_name: nil,
            keys: [],
            options: []

  @typedoc """
  Skogsra environment variable.
  """
  @type t :: %Env{
          cache: cache :: :ets.tab(),
          namespace: namespace :: namespace(),
          app_name: app_name :: app_name(),
          keys: keys :: keys(),
          options: options :: options()
        }

  @doc """
  Creates a new `Skogsra` environment variable.
  """
  @spec new(namespace(), app_name(), key(), options()) :: t()
  @spec new(namespace(), app_name(), keys(), options()) :: t()
  def new(namespace, app_name, keys, options) do
    cache = get_cache_name()
    new(cache, namespace, app_name, keys, options)
  end

  @doc false
  @spec new(:ets.tab(), namespace(), app_name(), key(), options()) :: t()
  @spec new(:ets.tab(), namespace(), app_name(), keys(), options()) :: t()
  def new(cache, namespace, app_name, keys, options)

  def new(cache, namespace, app_name, key, options) when is_atom(key) do
    new(cache, namespace, app_name, [key], options)
  end

  def new(cache, namespace, app_name, keys, options) when is_list(keys) do
    namespace = if is_nil(namespace), do: options[:namespace], else: namespace
    options = defaults(options)

    %Env{
      cache: cache,
      namespace: namespace,
      app_name: app_name,
      keys: keys,
      options: options
    }
  end

  @doc false
  @spec get_cache_name() :: :ets.tab()
  def get_cache_name, do: @cache

  @doc false
  def defaults(options) do
    options
    |> Keyword.put_new(:skip_system, false)
    |> Keyword.put_new(:skip_config, false)
    |> Keyword.put_new(:required, false)
    |> Keyword.put_new(:cached, true)
  end
end
