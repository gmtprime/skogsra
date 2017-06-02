defmodule Skogsra do
  @moduledoc """
  This library attempts to improve the use of OS environment variables and
  application configuration. You would create a settings module e.g:

  ```elixir
  defmodule Settings do
    use Skogsra

    # Rather equivalent to `System.get_env("POSTGRES_PORT") || 5432` (misses
    # the automatic casting to integer). Generates the function
    # `Settings.postgres_port/0`.
    @spec portgres_port() :: integer()
    system_env :postgres_port,
      default: 5432

    # Equivalent to
    # ```
    # System.get_env("POSTGRES_HOSTNAME") ||
    # (Application.get_env(:my_app, MyApp.Repo, []) |>
    #  Keyword.get(:hostname, "localhost"))
    # ```
    # Generates the function Settings.postgres_hostname/0
    @spec postgres_hostname() :: binary()
    app_env :postgres_hostname, :my_app, :hostname,
      domain: MyApp.Repo
      default: "localhost"
  end
  ```

  It can be used in the configuration file as well e.g:

  ```elixir
  config :my_app, MyApp.Repo,
    adapter: Ecto.Adapters.Postgres,
    hostname: Skogsra.get_env("POSTGRES_HOSTNAME", "localhost"),
    port: Skogsra.get_env_as(:integer, "POSTGRES_PORT", "5432"),
    (...)
  ```

  Or from a module:

  ```elixir
  defmodule MyApp do
    @port Skogsra.get_app_env "POSTGRES_PORT", :my_app, :port,
      domain: MyApp.Repo,
      default: 5432

    @spec get_port() :: integer()
    def get_port, do: @port
  end
  ```
  """
  require Logger

  @doc """
  For now is just equivalent to use `import Skogsra`.
  """
  defmacro __using__(_) do
    quote do
      import Skogsra
    end
  end

  @doc """
  Macro that receives the `name` of the OS environment variable and some
  optional `Keyword` list with `options` and generates a function with arity 0
  with the same name of the OS environment variable, but in lower case e.g.
  `"FOO"` would generate the function `foo/0`.
  
  The available options are:

    - `:static` - Whether the computation of the OS environment variable is
    done on compiling time or not. By default its value is `false`.
    - `:default` - Default value in case the OS environment variable doesn't
    exist. By default is `nil`.
    - `:type` - The type of the OS environment variable. By default is the type
    of the default value. If there is no default value, the default type is
    `binary`. The available types are `:binary`, `:integer`, `:float`,
    `:boolean` and `:atom`.

  e.g

  ```elixir
  defmodule Settings do
    use Skogsra

    system_env :foo,
      default: 42,
      type: :integer
  end
  ```

  This would generate the function `Settings.foo/0` that would search for
  the OS environment variable `"FOO"` and cast it to integer on runtime and
  defaults to `42`.
  """
  defmacro system_env(name, opts \\ []) do
    if Keyword.get(opts, :static, false) do
      Skogsra.static_system_env(name, opts)
    else
      Skogsra.runtime_system_env(name, opts)
    end
  end

  @doc """
  Macro that receives the `name` of the OS environment variable, the name of
  the `app`, the name of the option `key` and some optional `Keyword` list with
  `options` and generates a function with arity 0 with the same name of the OS
  environment variable, but in lower case e.g. `"FOO"` would generate the
  function `foo/0`.
  
  The available options are:

    - `:static` - Whether the computation of the OS environment variable or
    application configuration option is done on compiling time or not. By
    default its value is `false`.
    - `:default` - Default value in case the OS environment variable and the
    application configuration option don't exist. By default is `nil`.
    - `:type` - The type of the OS environment variable. By default is the type
    of the default value. If there is no default value, the default type is
    `binary`. The available types are `:binary`, `:integer`, `:float`,
    `:boolean` and `:atom`.
    - `:domain` - The `key` to search in the configuration file e.g in:
      ```elixir
      config :my_app, MyApp.Repo,
        adapter: Ecto.Adapters.Postgres,
        (...)
      ```
    the domain would be `MyApp.Repo`. By default, there is no domain.

  e.g

  ```elixir
  defmodule Settings do
    use Skogsra

    app_env :foo, :my_app, :foo,
      default: 42,
      type: :integer,
      domain: MyApp.Domain
  end
  ```

  This would generate the function `Settings.foo/0` that would search for
  the OS environment variable `"FOO"` and cast it to integer on runtime. If the
  OS environment variable is not found, attempts to search for the `:foo`
  configuration option for the application `:my_app` and the domain
  `MyApp.Domain`. If nothing is found either, it defaults to `42`.

  Calling `Settings.foo/0` without a domain set is equivalent to:

  ```elixir
  with value when not is_nil(value) <- System.get_env("FOO"),
       {number, _} <- Integer.parse(value) do
    number
  else
    _ ->
      Application.get_env(:my_app, :foo, 42)
  end
  ```

  Calling `Settings.foo/0` With a domain set is equivalent to:

  ```elixir
  with value when not is_nil(value) <- System.get_env("FOO"),
       {number, _} <- Integer.parse(value) do
    number
  else
    _ ->
      opts = Application.get_env(:my_app, MyApp.Domain, [])
      Keyword.get(opts, :foo, 42)
  end
  ```
  """
  defmacro app_env(name, app, key, opts \\ []) do
    if Keyword.get(opts, :static, false) do
      Skogsra.static_app_env(name, app, key, opts)
    else
      Skogsra.runtime_app_env(name, app, key, opts)
    end
  end

  @doc """
  Gets the OS environment variable by its `name` and cast it the the type of
  the `default` value. If no `default` value is provided, returns a string.
  If the OS environment variable is not found, returns the `default` value.

  ```elixir
  config :my_app, MyApp.Repo,
    adapter: Ecto.Adapters.Postgres,
    hostname: Skogsra.get_env("POSTGRES_HOSTNAME", "localhost"),
    (...)
  ```
  """
  @spec get_env(binary) :: term()
  @spec get_env(binary, term) :: term()
  def get_env(name, default \\ nil) when is_binary(name) do
    default
    |> type?()
    |> get_env_as(name, default)
  end

  @doc """
  Gets the OS environment variable by its `name` and casts it to the provided
  `type`. If the OS environment variable is not found, returns the `default`
  value.

  ```elixir
  config :my_app, MyApp.Repo,
    adapter: Ecto.Adapters.Postgres,
    hostname: Skogsra.get_env("POSTGRES_HOSTNAME", "localhost"),
    port: Skogsra.get_env_as(:integer, "POSTGRES_PORT", 5432),
    (...)
  ```
  """
  @spec get_env_as(atom(), binary()) :: term()
  @spec get_env_as(atom(), binary(), term()) :: term()
  def get_env_as(type, name, default \\ nil) when is_binary(name) do
    default = cast_default(default, type)
    with {:ok, value} <- do_get_env_as(type, name, default) do
      value
    else
      {:error, message} ->
        Logger.error(message)
        default
    end
  end

  @doc """
  Gets the OS environment variable by its name. If it's not found, attempts to
  get the application configuration option by the `app` name and the option
  `key`. Optionally receives a `Keyword` list of `options`
  
  i.e:
    - `:default` - Default value in case the OS environment variable and the
    application configuration option don't exist. By default is `nil`.
    - `:type` - The type of the OS environment variable. By default is the type
    of the default value. If there is no default value, the default type is
    `binary`. The available types are `:binary`, `:integer`, `:float`,
    `:boolean` and `:atom`.
    - `:domain` - The `key` to search in the configuration file e.g in:
      ```elixir
      config :my_app, MyApp.Repo,
        adapter: Ecto.Adapters.Postgres,
        hostname: "localhost",
        (...)
      ```
    the domain would be `MyApp.Repo`. By default, there is no domain.

  e.g:

  ```elixir
  defmodule MyApp do
    def get_hostname do
      get_app_env("POSTGRES_HOSTNAME", :my_app, :hostname, domain: MyApp.Repo)
    end
  end
  ```
  """
  @spec get_app_env(binary(), atom(), atom()) :: term()
  @spec get_app_env(binary(), atom(), atom(), list()) :: term()
  def get_app_env(name, app, key, options \\ []) when is_binary(name) do
    default = Keyword.get(options, :default, nil)
    type = Keyword.get(options, :type, type?(default))
    with default = cast_default(default, type),
         value when is_nil(value) <- get_env_as(type, name),
         domain = Keyword.get(options, :domain),
         {:ok, value} <- do_get_app_env(type, app, domain, key, default) do
      value
    else
      {:error, _} -> default
      value -> value
    end
  end

  #########
  # Helpers

  @doc false
  def runtime_system_env(name, opts) do
    default = Keyword.get(opts, :default)
    type = Keyword.get(opts, :type, type?(default))
    env_name = name |> Atom.to_string() |> String.upcase()
    quote do
      def unquote(name)() do
        Skogsra.get_env_as(unquote(type), unquote(env_name), unquote(default))
      end
    end
  end

  @doc false
  def static_system_env(name, opts) do
    default = Keyword.get(opts, :default)
    type = Keyword.get(opts, :type, type?(default))
    env_name = name |> Atom.to_string() |> String.upcase()
    value = Skogsra.get_env_as(type, env_name, default)
    quote do
      def unquote(name)(), do: unquote(value)
    end
  end

  @doc false
  def runtime_app_env(name, app, key, opts) do
    env_name = name |> Atom.to_string() |> String.upcase()
    quote do
      def unquote(name)() do
        Skogsra.get_app_env(
          unquote(env_name),
          unquote(app),
          unquote(key),
          unquote(opts)
        )
      end
    end
  end

  @doc false
  def static_app_env(name, app, key, opts) do
    env_name = name |> Atom.to_string() |> String.upcase()
    value = Skogsra.get_app_env(env_name, app, key, opts)
    quote do
      def unquote(name)(), do: unquote(value)
    end
  end

  @doc false
  def do_get_app_env(type, app, nil, key, default) do
    value = Application.get_env(app, key, default)
    cast(value, type)
  end
  def do_get_app_env(type, app, domain, key, default) do
    case Application.get_env(app, domain) do
      nil ->
        default
      opts ->
        value = Keyword.get(opts, key, default)
        cast(value, type)
    end
  end

  @doc false
  def do_get_env_as(type, var, default \\ nil) do
    value = System.get_env(var)
    if is_nil(value), do: {:ok, default}, else: cast(value, type)
  end

  @doc false
  def type?(nil), do: :any
  def type?(value) when is_integer(value), do: :integer
  def type?(value) when is_float(value), do: :float
  def type?(value) when is_boolean(value), do: :boolean
  def type?(value) when is_atom(value), do: :atom
  def type?(_), do: :any

  @doc false
  def cast_default(default, type) do
    with {:ok, default} <- cast(default, type) do
      default
    else
      _ -> nil
    end
  end

  @doc false
  def cast(value, :integer) when is_binary(value) do
    value = String.trim(value)
    with {number, ""} <- Integer.parse(value) do
      {:ok, number}
    else
      {_, rest} ->
        {:error, "#{rest} from #{value} couldn't be casted to integer"}
      :error ->
        {:error, "Cannot cast #{inspect value} to integer"}
    end
  end
  def cast(value, :float) when is_binary(value) do
    value = String.trim(value)
    with {number, ""} <- Float.parse(value) do
      {:ok, number}
    else
      {_, rest} ->
        {:error, "#{rest} from #{value} couldn't be casted to float"}
      :error ->
        {:error, "Cannot cast #{inspect value} to float"}
    end
  end
  def cast(value, :boolean) when is_binary(value) do
    real_value =
      value
      |> String.downcase()
      |> String.trim()
      |> String.to_atom()
    if is_boolean(real_value) do
      {:ok, real_value}
    else
      {:error, "Cannot cast #{inspect value} to boolean"}
    end
  end
  def cast(value, :atom) when is_binary(value) do
    {:ok, String.to_atom(value)}
  end
  def cast(value, _), do: {:ok, value}
end
