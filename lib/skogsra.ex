defmodule Skogsra do
  @moduledoc """
  > The _Skogsrå_ was a mythical creature of the forest that appears in the form
  > of a small, beautiful woman with a seemingly friendly temperament. However,
  > those who are enticed into following her into the forest are never seen
  > again.

  This library attempts to improve the use of OS environment variables for
  application configuration:

  * Automatic type casting of values.
  * Automatic documentation generation for variables.
  * Variable defaults.
  * Runtime reloading.
  * Runtime setting the value with the name of the variable.

  ## Small Example

  You would create a settings module e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    @envdoc "My hostname"
    app_env :my_hostname, :myapp, :hostname,
      default: "localhost"
  end
  ```

  Calling `MyApp.Settings.my_hostname()` will retrieve the value for the
  hostname in the following order:

  1. From the OS environment variable `$MYAPP_HOSTNAME`.
  2. From the configuration file e.g:
  ```
  config :myapp,
    hostname: "my.custom.host"
  ```
  3. From the default value if it exists (In this case, it would return
  `"localhost"`).

  ## Handling different environments

  If it's necessary to keep several environments, it's possible to use a
  `namespace` e.g:

  Calling `MyApp.Settings.my_hostname(Test)` will retrieve the value for the
  hostname in the following order:

  1. From the OS environment variable `$TEST_MYAPP_HOSTNAME`.
  2. From the configuration file e.g:
  ```
  config :myapp, Test,
    hostname: "my.custom.test.host"
    ```
  3. From the default value if it exists.

  ## Required variables

  It is possible to set a environment variable as required with the `required`
  option e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    @envdoc "My port"
    app_env :my_port, :myapp, :port,
      required: true
  end
  ```

  If the variable `$MYAPP_PORT` is undefined and the configuration is missing,
  calling to `MyApp.Settings.my_port()` will return an error tuple. Calling
  `$MyApp.Settings.my_port!()` (with the bang) will raise a runtime
  exception.

  ## Automatic casting

  If the default value is set, the OS environment variable value will be casted
  as the same type of the default value. Otherwise, it is possible to set the
  type for the variable with the option `type`. The available types are
  `:binary` (default), `:integer`, `:float`, `:boolean` and `:atom`.
  Additionally, you can create a function to cast the value and specify it as
  `{module_name, function_name}` e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    @envdoc "My channels"
    app_env :my_channels, :myapp, :channels,
      type: {__MODULE__, channels},
      required: true

    def channels(value), do: String.split(value, ", ")
  end
  ```

  If `$MYAPP_CHANNELS`'s value is `"ch0, ch1, ch2"` then the casted value
  will be `["ch0", "ch1", "ch2"]`.

  ## Setting and reloading variables

  It's possible to set a value for the variable at runtime with e.g.
  `MyApp.Settings.put_my_hostname("my.other.hostname")`.

  Also, for debugging purposes is possible to reload variables at runtime with
  e.g. `MyApp.Settings.reload_my_hostname()`.

  ## Using with _Hab_

  [_Hab_](https://github.com/alexdesousa/hab) is an
  [Oh My ZSH](https://github.com/robbyrussell/oh-my-zsh) plugin for loading OS
  environment variables automatically.

  By default, _Hab_ will try to load `.envrc` file, but it's possible to have
  several of those files for different purposes e.g:

  - `.envrc.prod` for production OS variables.
  - `.envrc.test` for testing OS variables.
  - `.envrc` for development variables.

  _Hab_ will load the development variables by default, but it can load the
  other files using the command `load_hab <extension>` e.g. loading
  `.envrc.prod` would be as follows:

  ```bash
  ~/my_project $ load_hab prod
  [SUCCESS]  Loaded hab [/home/user/my_project/.envrc.prod]
  ```
  """
  alias Skogsra.Core
  alias Skogsra.Docs
  alias Skogsra.Env

  ########
  # Macros

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
  use the default name. This option is ignoredif the option `skip_system` is
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

  It will generate the functions `db_password/0` and `db_password/1`. The
  optional parameter is useful to specify namespaces.

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
  defmacro app_env(function_name, app_name, keys, options \\ []) do
    bang! = String.to_atom("#{function_name}!")
    reload = String.to_atom("reload_#{function_name}")
    put = String.to_atom("put_#{function_name}")

    quote do
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
      @spec unquote(function_name)(namespace :: Skogsra.Env.namespace()) ::
              {:ok, term()} | {:error, term()}
      def unquote(function_name)(namespace \\ nil) do
        app_name = unquote(app_name)
        keys = unquote(keys)
        options = unquote(options)

        env = Env.new(namespace, app_name, keys, options)
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
      @spec unquote(bang!)(namespace :: Skogsra.Env.namespace()) ::
              {:ok, term()} | {:error, term()}
      def unquote(bang!)(namespace \\ nil) do
        app_name = unquote(app_name)
        keys = unquote(keys)
        options = unquote(options)

        env = Env.new(namespace, app_name, keys, options)
        Core.get_env!(env)
      end

      # Reloads the variable.
      @doc Docs.gen_reload_docs(__MODULE__, unquote(function_name))
      @spec unquote(reload)() :: {:ok, term()} | {:error, term()}
      @spec unquote(reload)(namespace :: Skogsra.Env.namespace()) ::
              {:ok, term()} | {:error, term()}
      def unquote(reload)(namespace \\ nil) do
        app_name = unquote(app_name)
        keys = unquote(keys)
        options = unquote(options)

        env = Env.new(namespace, app_name, keys, options)
        Core.reload_env(env)
      end

      # Puts a new value to a variable.
      @doc Docs.gen_put_docs(__MODULE__, unquote(function_name))
      @spec unquote(put)(value :: term()) :: :ok | {:error, term()}
      @spec unquote(put)(
              value :: term(),
              namespace :: Skogsra.Env.namespace()
            ) :: :ok | {:error, term()}
      def unquote(put)(value, namespace \\ nil) do
        app_name = unquote(app_name)
        keys = unquote(keys)
        options = unquote(options)

        env = Env.new(namespace, app_name, keys, options)
        Core.put_env(env, value)
      end
    end
  end
end
