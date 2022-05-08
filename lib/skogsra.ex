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
  alias Skogsra.App
  alias Skogsra.Core
  alias Skogsra.Docs
  alias Skogsra.Env
  alias Skogsra.Spec
  alias Skogsra.Template

  @doc """
  Imports `app_env/3` and `app_env/4`. Additionally generates the function
  `template(`
  For now is just equivalent to use `import Skogsra`.
  """
  defmacro __using__(_) do
    quote do
      import Skogsra, only: [app_env: 3, app_env: 4]

      Module.register_attribute(__MODULE__, :definitions, accumulate: true)

      @before_compile Skogsra
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Creates a template for OS environment variables given a `filename`.
      Additionally, it can receive a list of options:

      - `type`: What kind of file it will generate (`:elixir`, `:unix`,
        `:windows`).
      - `namespace`: Namespace for the variables.
      """
      @spec template(Path.t()) :: :ok | {:error, File.posix()}
      @spec template(Path.t(), keyword()) :: :ok | {:error, File.posix()}
      def template(filename, options \\ [])

      def template(filename, options) do
        options
        |> __get_definitions__()
        |> Template.generate(filename)
      end

      @doc """
      Validates that all required variables are present.
      Returns `:ok` if they are, `{:error, errors}` if they are not. `errors`
      will be a list of all errors encountered while getting required variables.

      It is possible to provide a `namespace` as argument (defaults to `nil`).
      """
      @spec validate() :: :ok | {:error, [binary()]}
      @spec validate(Env.namespace()) :: :ok | {:error, [binary()]}
      def validate(namespace \\ nil)

      def validate(namespace) do
        errors = __get_required_errors__(namespace)

        if errors == [] do
          :ok
        else
          {:error, errors}
        end
      end

      @doc """
      Validates that all required variables are present.
      Returns `:ok` if they are, raises if they're not.

      It is possible to provide a `namespace` as argument (defaults to `nil`).
      """
      @spec validate!() :: :ok | no_return()
      @spec validate!(Env.namespace()) :: :ok | no_return()
      def validate!(namespace \\ nil) do
        with {:error, errors} <- validate(namespace) do
          error_string = Enum.join(errors, ", ")
          raise error_string
        end
      end

      @doc """
      Preloads all variables in a `namespace` if supplied.
      """
      @spec preload() :: :ok
      @spec preload(Env.namespace()) :: :ok
      def preload(namespace \\ nil) do
        namespace
        |> __get_all_envs__()
        |> Enum.each(&App.preload/1)

        :ok
      end

      @spec __get_definitions__(keyword()) :: [Template.t()]
      defp __get_definitions__(options) do
        namespace = options[:namespace]
        type = options[:type] || :elixir

        @definitions
        |> Stream.map(fn {docs, name} ->
          {docs, apply(__MODULE__, name, [namespace])}
        end)
        |> Stream.filter(fn {docs, _env} -> docs != false end)
        |> Stream.filter(fn {_docs, env} -> Env.os_env(env) != "" end)
        |> Stream.map(fn {docs, env} -> %{docs: docs, env: env, type: type} end)
        |> Enum.map(&Template.new(&1))
      end

      @spec __get_required_errors__(Env.namespace()) :: [binary()]
      defp __get_required_errors__(namespace) do
        namespace
        |> __get_all_envs__()
        |> Stream.filter(&Env.required?/1)
        |> Enum.reduce([], fn env, errors ->
          case Core.get_env(env) do
            {:ok, _value} ->
              errors

            {:error, error} ->
              [error | errors]
          end
        end)
      end

      @spec __get_all_envs__(Env.namespace()) :: Enumerable.t()
      defp __get_all_envs__(namespace) do
        @definitions
        |> Stream.map(&elem(&1, 1))
        |> Stream.map(&apply(__MODULE__, &1, [namespace]))
      end
    end
  end

  @doc """
  Creates a function to retrieve specific environment/application variables
  values.

  The function created is named `function_name` and will get the value
  associated with an application called `app_name` and one or several
  `parameters` keys. Optionally, receives a list of `options`.

  Available options:

  Option          | Type                    | Default              | Description
  :-------------- | :---------------------- | :------------------- | :----------
  `default`       | `any`                   | `nil`                | Sets the Default value for the variable.
  `type`          | `Skogsra.Env.type()`    | `:binary`            | Sets the explicit type for the variable.
  `os_env`        | `binary`                | autogenerated        | Overrides automatically generated OS environment variable name.
  `binding_order` | `Skogra.Env.bindings()` | `[:system, :config]` | Sets the load order for variable binding.
  `binding_skip`  | `Skogra.Env.bindings()` | `[]`                 | Which variable bindings should be skipped.
  `required`      | `boolean`               | `false`              | Whether the variable is required or not.
  `cached`        | `boolean`               | `true`               | Whether the variable should be cached or not.
  `namespace`     | `module`                | `nil`                | Overrides any namespace.

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

  A call to `db_password/0` will try to get a value:

  1. From the OS environment variable `$MYAPP_MYDB_PASSWORD` (can be overriden
     by the option `os_env`).
  2. From the configuration file e.g:
     ```
     config :myapp,
       mydb: [password: "some password"]
     ```
  3. From the default value if it exists (In this case, it would return
     `"password"`).

  A call to `db_password/1` with namespace `Test` will try to get a value:

  1. From the OS environment variable `$TEST_MYAPP_MYDB_PASSWORD`.
  2. From the configuration file e.g:
     ```
     config :myapp, Test,
       mydb: [password: "some test password"]
     ```
  3. From the OS environment variable `$MYAPP_MYDB_PASSWORDT`.
  4. From the configuraton file e.g:
     ```
     config :myapp,
       mydb: [password: "some password"]
     ```
  5. From the default value if it exists. In our example, `"password"`.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro app_env(function_name, app_name, keys, options \\ []) do
    definition = String.to_atom("__#{function_name}__")
    bang! = String.to_atom("#{function_name}!")
    reload = String.to_atom("reload_#{function_name}")
    put = String.to_atom("put_#{function_name}")

    quote do
      Module.put_attribute(
        __MODULE__,
        :definitions,
        {Module.get_attribute(__MODULE__, :envdoc, false), unquote(definition)}
      )

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
             Module.get_attribute(__MODULE__, :envdoc, false)
           )
      unquote(Spec.gen_full_spec(function_name, options))
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
             Module.get_attribute(__MODULE__, :envdoc, false)
           )
      unquote(Spec.gen_bang_spec(bang!, options))
      def unquote(bang!)(namespace \\ nil)

      def unquote(bang!)(namespace) do
        env = unquote(definition)(namespace)
        Core.get_env!(env)
      end

      # Reloads the variable.
      @doc Docs.gen_reload_docs(
             __MODULE__,
             unquote(function_name),
             Module.get_attribute(__MODULE__, :envdoc, false)
           )
      unquote(Spec.gen_reload_spec(reload, options))
      def unquote(reload)(namespace \\ nil)

      def unquote(reload)(namespace) do
        env = unquote(definition)(namespace)
        Core.reload_env(env)
      end

      # Puts a new value to a variable.
      @doc Docs.gen_put_docs(
             __MODULE__,
             unquote(function_name),
             Module.get_attribute(__MODULE__, :envdoc, false)
           )
      unquote(Spec.gen_put_spec(put, options))
      def unquote(put)(value, namespace \\ nil)

      def unquote(put)(value, namespace) do
        env = unquote(definition)(namespace)
        Core.put_env(env, value)
      end
    end
  end
end
