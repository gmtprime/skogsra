defmodule Skogsra.Env do
  @moduledoc """
  This module defines a `Skogsra` environment variable.
  """
  alias __MODULE__

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
  Types.
  """
  @type type ::
          :binary
          | :integer
          | :float
          | :boolean
          | :atom
          | :module
          | :unsafe_module
          | module()

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
  defstruct namespace: nil,
            app_name: nil,
            keys: [],
            options: []

  @typedoc """
  Skogsra environment variable.
  """
  @type t :: %Env{
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
  def new(namespace, app_name, keys, options)

  def new(namespace, app_name, key, options) when is_atom(key) do
    new(namespace, app_name, [key], options)
  end

  def new(namespace, app_name, keys, options) when is_list(keys) do
    namespace = if is_nil(namespace), do: options[:namespace], else: namespace
    options = defaults(options)

    %Env{
      namespace: namespace,
      app_name: app_name,
      keys: keys,
      options: options
    }
  end

  @doc """
  Whether the `Skogsra` environment variable should skip system or not.
  """
  @spec skip_system?(t()) :: boolean()
  def skip_system?(%Env{options: options}) do
    case options[:skip_system] do
      true -> true
      _ -> false
    end
  end

  @doc """
  Whether the `Skogsra` environment variable should skip config or not.
  """
  @spec skip_config?(t()) :: boolean()
  def skip_config?(%Env{options: options}) do
    case options[:skip_config] do
      true -> true
      _ -> false
    end
  end

  @doc """
  Gets the OS variable name for the `Skogsra` environment variable.
  """
  @spec os_env(t()) :: binary()
  def os_env(%Env{options: options} = env) do
    with value when not is_binary(value) <- options[:os_env] do
      namespace = gen_namespace(env)
      app_name = gen_app_name(env)
      keys = gen_keys(env)

      "#{namespace}#{app_name}_#{keys}"
    end
  end

  @doc """
  Gets the type of the `Skogsra` environment variable.
  """
  @spec type(t()) :: type()
  def type(%Env{options: options} = env) do
    with nil <- options[:type] do
      env
      |> default()
      |> get_type()
    end
  end

  @doc """
  Gets the default value for a `Skogsra` environment variable.
  """
  @spec default(t()) :: term()
  def default(%Env{options: options}) do
    options[:default]
  end

  @doc """
  Whether the `Skogsra` environment variable is required or not.
  """
  @spec required?(t()) :: boolean()
  def required?(%Env{options: options}) do
    case options[:required] do
      true -> true
      _ -> false
    end
  end

  @doc """
  Whether the `Skogsra` environment variable is cached or not.
  """
  @spec cached?(t()) :: boolean()
  def cached?(%Env{options: options}) do
    case options[:cached] do
      false -> false
      _ -> true
    end
  end

  #########
  # Helpers

  @doc false
  def defaults(options) do
    options
    |> Keyword.put_new(:skip_system, false)
    |> Keyword.put_new(:skip_config, false)
    |> Keyword.put_new(:required, false)
    |> Keyword.put_new(:cached, true)
  end

  @doc false
  @spec gen_namespace(t()) :: binary()
  def gen_namespace(env)

  def gen_namespace(%Env{namespace: nil}) do
    ""
  end

  def gen_namespace(%Env{namespace: namespace}) do
    value =
      namespace
      |> Module.split()
      |> Stream.map(&String.upcase/1)
      |> Enum.join("_")

    "#{value}_"
  end

  @doc false
  @spec gen_app_name(t()) :: binary()
  def gen_app_name(env)

  def gen_app_name(%Env{app_name: app_name}) do
    app_name
    |> Atom.to_string()
    |> String.upcase()
  end

  @doc false
  @spec gen_keys(t()) :: binary()
  def gen_keys(env)

  def gen_keys(%Env{keys: keys}) do
    keys
    |> Stream.map(&Atom.to_string/1)
    |> Stream.map(&String.upcase/1)
    |> Enum.join("_")
  end

  @doc false
  @spec get_type(term()) :: type()
  def get_type(value)

  def get_type(nil), do: :binary
  def get_type(value) when is_binary(value), do: :binary
  def get_type(value) when is_integer(value), do: :integer
  def get_type(value) when is_float(value), do: :float
  def get_type(value) when is_boolean(value), do: :boolean
  def get_type(value) when is_atom(value), do: :atom
  def get_type(_), do: :binary
end
