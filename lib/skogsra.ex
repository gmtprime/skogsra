defmodule Skogsra do
  @moduledoc """
  This module defines the macros needed to use `Skogsra` e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    @envdoc "My hostname"
    app_env :my_hostname, :myapp, :hostname,
      default: "localhost"
  end
  ```
  """
  alias Skogsra.Core
  alias Skogsra.Docs
  alias Skogsra.Env

  @doc """
  For now is just equivalent to use `import Skogsra`.
  """
  defmacro __using__(_) do
    quote do
      import Skogsra
    end
  end

  @doc """
  Creates a function to retrieve specific environment/application variables
  values.

  The function created is named `function_name` and will get the value
  associated with an application called `app_name` and one or several
  `parameters` keys. Optionally, receives a list of `options`.

  Options:
  - `default` - Default value for the variable in case is not present.
  - `type` - Type of the variable. Used for casting the value. By default,
  casts the value to the same type of the default value. If the default value
  is not present, defaults to `:binary`. The available values are: `:binary`,
  `:integer`, `:float`, :boolean, `:atom`. Additionally, you can provide
  `{module, function}` for custom types. The function must receive the
  binary and return the custom type.
  - `os_env` - Alias for the variable in the OS. If the alias is `nil` will
  use the default name. This option is ignored if the option `skip_system` is
  `true` (default is `false`).
  - `namespace` - Namespace of the variable.
  - `skip_system` - If `true`, doesn't look for the variable value in the
  system. Defaults to `false`.
  - `skip_config` - If `true`, doesn't look for the variable value in the
  configuration. Defaults to `false`.
  - `required` - Errors when the value is `nil`. Defaults to `false`.
  - `cached` - Caches the value on the first read. Defaults to `true`.

  e.g:

  For the following declaration:

  ```
  app_env :db_password, :myapp, [:mydb, :password],
    default: "password",
  ```

  will generate:

  - `db_password/0` and `db_password/1` for getting the variable's value
  without or with namespace respectively. It returns `:ok` and `:error`
  tuples.
  - `db_password!/0` and `db_password!/1` for getting the variable's value
  without or with namespace respectively. It fails on error.
  - `reload_db_password/0` and `reload_db_password/1` for reloading the
  variable's value in the cache without or with namespace respectively.
  - `put_db_password/1` and `put_db_password/2` for settings a new value for
  the variable directly to the cache without or with namespace respectively.

  A call to `db_password/0` will try to:

  1. Look for the value of `$MYAPP_MYDB_PASSWORD` OS environment variable. If
     it's `nil`, then it will try 2.
  2. Look for the value in the configuration e.g:
     ```
     config :myapp,
       mydb: [password: "some password"]
     ```
     If it's `nil`, then it will try 3.
  3. Return the value of the default value or `nil`.

  A call to `db_password/1` with namespace `Test` will try to:

  1. Look for the value of `$TEST_MYAPP_MYDB_PASSWORD` OS environment variable.
     If it's `nil`, then it will try 2.
  2. Look for the value in the configuration e.g:
     ```
     config :myapp, Test,
       mydb: [password: "some password"]
     ```
     If it's `nil`, then it will try 3.
     3. Return the value of the default value or `nil`.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro app_env(function_name, app_name, keys, options \\ []) do
    definition = String.to_atom("__#{function_name}__")
    bang! = String.to_atom("#{function_name}!")
    reload = String.to_atom("reload_#{function_name}")
    put = String.to_atom("put_#{function_name}")

    quote do
      @doc false
      @spec unquote(definition)() :: Env.t()
      @spec unquote(definition)(namespace :: Env.namespace()) :: Env.t()
      def unquote(definition)(namespace \\ nil) do
        app_name = unquote(app_name)
        keys = unquote(keys)
        options = unquote(options)

        Env.new(namespace, app_name, keys, options)
      end

      # Function to get the variable's value. Errors when is required and does
      # not exist.
      @doc Docs.gen_full_docs(
             __MODULE__,
             unquote(function_name),
             unquote(app_name),
             unquote(keys),
             unquote(options),
             Module.get_attribute(__MODULE__, :envdoc)
           )
      @spec unquote(function_name)() :: {:ok, term()} | {:error, term()}
      @spec unquote(function_name)(Env.namespace()) ::
              {:ok, term()} | {:error, term()}
      def unquote(function_name)(namespace \\ nil)

      def unquote(function_name)(namespace) do
        env = unquote(definition)(namespace)
        Core.get_env(env)
      end

      # Function to get the variable's value. Fails when is required and does
      # not exist,
      @doc Docs.gen_short_docs(
             __MODULE__,
             unquote(function_name),
             Module.get_attribute(__MODULE__, :envdoc)
           )
      @spec unquote(bang!)() :: term() | no_return()
      @spec unquote(bang!)(Env.namespace()) :: term() | no_return()
      def unquote(bang!)(namespace \\ nil)

      def unquote(bang!)(namespace) do
        env = unquote(definition)(namespace)
        Core.get_env!(env)
      end

      # Reloads the variable.
      @doc Docs.gen_reload_docs(__MODULE__, unquote(function_name))
      @spec unquote(reload)() :: {:ok, term()} | {:error, term()}
      @spec unquote(reload)(Env.namespace()) ::
              {:ok, term()} | {:error, term()}
      def unquote(reload)(namespace \\ nil)

      def unquote(reload)(namespace) do
        env = unquote(definition)(namespace)
        Core.reload_env(env)
      end

      # Puts a new value to a variable.
      @doc Docs.gen_put_docs(__MODULE__, unquote(function_name))
      @spec unquote(put)(term()) :: :ok | {:error, term()}
      @spec unquote(put)(term(), Env.namespace()) :: :ok | {:error, term()}
      def unquote(put)(value, namespace \\ nil)

      def unquote(put)(value, namespace) do
        env = unquote(definition)(namespace)
        Core.put_env(env, value)
      end
    end
  end
end
