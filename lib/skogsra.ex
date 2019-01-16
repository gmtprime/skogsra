defmodule Skogsra do
  @moduledoc """
  > The _Skogsrå_ was a mythical creature of the forest that appears in the form
  > of a small, beautiful woman with a seemingly friendly temperament. However,
  > those who are enticed into following her into the forest are never seen
  > again.

  This library attempts to improve the use of OS environment variables for
  application configuration:

    * Automatic type casting of values.
    * Configuration options documentation.
    * Variables defaults.

  ## Small Example

  You would create a settings module e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

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

    app_env :my_hostname, :myapp, :port,
      required: true
  end
  ```

  If the variable `$MYAPP_PORT` is undefined and the configuration is missing,
  calling to `MyApp.Settings.my_hostname()` will return an error tuple. Calling
  `$MyApp.Settings.my_hostname!()` (with the bang) will raise a runtime
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

    app_env :my_channels, :myapp, :channels,
      type: {__MODULE__, channels},
      required: true

    def channels(value), do: String.split(value, ", ")
  end
  ```

  If `$MYAPP_CHANNELS`'s value is `"ch0, ch1, ch2"` then the casted value
  will be `["ch0", "ch1", "ch2"]`.

  ## Configuration definitions

  Calling `MyApp.Settings.my_hostname(nil, :system)` will print the expected OS
  environment variable name and `MyApp.Settings.my_hostname(nil, :config)` will
  print the expected `Mix` configuration. If the `namespace` is necessary, pass
  it as first argument.

  ## Reloading

  For debugging purposes is possible to reload variables at runtime with
  `MyApp.Settings.my_hostname(nil, :reload)`.

  ## Recommended Usage

  The recommended way of using this project is to define a `.env` file in the
  root of your project with the variables that you want to define e.g:

  ```
  export MYSERVICE_PORT=1234
  ```

  and then when `source`ing the file right before you execute your application.
  In `bash` (or `zsh`) would be like this:

  ```
  $ source .env
  ```

  The previous step can be automated by adding the following code to your
  `~/.bashrc` (or `~/.zshrc`):

  ```
  #################
  # BEGIN: Auto env

  export LAST_ENV=

  function auto_env_on_chpwd() {
    env_type="$1"
    env_file="$PWD/.env"
    if [ -n "$env_type" ]
    then
      env_file="$PWD/.env.$env_type"
      if [ ! -r "$env_file" ]
      then
        echo -e "\e[33mFile $env_file does not exist.\e[0m"
        env_file="$PWD/.env"
      fi
    fi

    if [ -n "$LAST_ENV" ] && [ -r "$LAST_ENV" ]
    then
      UNSET=$(
        cat $LAST_ENV |
        sed -e 's/^export \([0-9a-zA-Z\_]*\)=.*$/unset \1/'
      )
      source <(echo "$UNSET")
      echo -e "\e[33mUnloaded ENV VARS defined in \"$LAST_ENV\"\e[0m"
      export LAST_ENV=
    fi

    if [ -r "$env_file" ]
    then
      export LAST_ENV="$env_file"
      source $LAST_ENV
      echo -e "\e[32mLoaded \"$LAST_ENV\"\e[0m"
    fi
  }

  chpwd_functions=(${chpwd_functions[@]} "auto_env_on_chpwd")

  if [ -n "$TMUX" ]
  then
    auto_env_on_chpwd
  fi

  alias change_to='function _change_to() {auto_env_on_chpwd $1}; _change_to'

  # END: Auto env
  ###############
  ```

  The previous code will attempt to `source` any `.env` file every time you
  change directory e.g:

  ```
  /home/alex $ cd my_app
  Loaded "/home/alex/my_app/.env"

  /home/alex/my_app $ echo "$MYSERVICE_PORT"
  1234
  ```

  Additionally, the command `change_to <ENV>` is included. To keep your `prod`,
  `dev` and `test` environment variables separated, just create a
  `.env.${MIX_ENV}` in the root directory of your project. And when you want to
  use the variables set in one of those files, just run the following:

  ```
  $ change_to dev # Will use `.env.dev` instead of `.env`
  ```
  """
  require Logger

  @cache :skogsra_cache

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
  `properties` keys. Optionally, receives a list of `options`.

  Options:
  - `default` - Default value for the variable in case is not present.
  - `type` - Type of the variable. Used for casting the value. By default,
  casts the value to the same type of the default value. If the default value
  is not present, defaults to `:binary`. The available values are: `:binary`,
  `:integer`, `:float`, :boolean, `:atom`. Additionally, you can provide
  `{module, function}` for custom types. The function must receive the
  binary and return the custom type.
  - `alias` - Alias for the variable in the OS. If the alias is `nil` will
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
  defmacro app_env(function_name, app_name, properties, options \\ []) do
    function_name! = String.to_atom("#{function_name}!")

    quote do
      @spec unquote(function_name)() :: {:ok, term()} | {:error, term()}
      @spec unquote(function_name)(
        namespace :: atom()
      ) :: {:ok, term()} | {:error, term()}
      @spec unquote(function_name)(
        namespace :: atom(),
        type :: :run | :reload | :system | :config
      ) :: {:ok, term()} | {:error, term()}
      def unquote(function_name)(namespace \\ nil, type \\ :run) do
        app_name = unquote(app_name)
        properties = unquote(properties)
        options = unquote(options)

        case type do
          :run ->
            Skogsra.get_env(namespace, app_name, properties, options)

          :reload ->
            Skogsra.reload(namespace, app_name, properties, options)

          :config ->
            Skogsra.sample_app_env(namespace, app_name, properties, options)

          :system ->
            Skogsra.sample_system_env(namespace, app_name, properties, options)
        end
      end

      @doc """
      Same as #{unquote(__MODULE__)}.#{unquote(function_name)}/1 but fails on
      error.
      """
      @spec unquote(function_name!)() :: term() | no_return()
      @spec unquote(function_name!)(
        namespace :: atom()
      ) :: {:ok, term()} | {:error, term()}
      def unquote(function_name!)(namespace \\ nil) do
        case unquote(function_name)(namespace) do
          {:ok, value} ->
            value

          {:error, error} ->
            Logger.error(fn -> IO.inspect(error) end)
            raise RuntimeError, message: error
        end
      end
    end
  end

  ##########
  # Defaults

  ##
  # Gets the name of the cache.
  @doc false
  def get_cache_name, do: @cache

  ##
  # Whether, when getting the variable's value, `:system` or `:config` should
  # be skipped.
  @doc false
  def skip?(:system, options), do: Keyword.get(options, :skip_system, false)
  def skip?(:config, options), do: Keyword.get(options, :skip_config, false)

  ##
  # Gets namespace.
  @doc false
  def get_namespace(options), do: Keyword.get(options, :namespace)

  ##
  # Gets default.
  @doc false
  def get_default(options), do: Keyword.get(options, :default)

  ##
  # Gets variable type.
  @doc false
  def get_type(options), do: Keyword.get(options, :type, :binary)

  ##
  # Whether the variable is cached or not.
  @doc false
  def cached?(options), do: Keyword.get(options, :cached, true)

  ##
  # Whether the variable is required or not.
  @doc false
  def required?(options), do: Keyword.get(options, :required, false)

  ##
  # Gets OS environment variable alias.
  @doc false
  def get_alias(options), do: Keyword.get(options, :alias)

  ##########
  # Samplers

  ##
  # Prints the name of the OS environment variable according to its definition.
  @doc false
  @spec sample_system_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: :ok
  def sample_system_env(namespace, app_name, property, options)
        when is_atom(property) do
    sample_system_env(namespace, app_name, [property], options)
  end

  def sample_system_env(namespace, app_name, properties, options) do
    if skip?(:system, options) do
      Logger.warn(fn -> "OS environment variable is been ignored" end)
    else
      name = gen_env_var(namespace, app_name, properties, options)
      Logger.info(fn -> "OS environment variable name: $#{name}" end)
    end
  end

  ##
  # Prints a configuration for the application environment variable.
  @doc false
  @spec sample_app_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: :ok
  def sample_app_env(namespace, app_name, property, options)
        when is_atom(property) do
    sample_app_env(namespace, app_name, [property], options)
  end

  def sample_app_env(namespace, app_name, properties, options) do
    if skip?(:config, options) do
      Logger.warn(fn -> "Application environment variable is been ignored" end)
    else
      code = gen_config_code(namespace, app_name, properties, options)
      Logger.info(fn ->
        "Application environment variable sample:\n\n #{code}"
      end)
    end
  end

  ##
  # Generates a string with the `Mix` configuration code.
  @doc false
  @spec gen_config_code(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: binary()
  def gen_config_code(nil, app_name, properties, options) do
    case get_namespace(options) do
      nil ->
        "config #{inspect app_name},\n" <>
        expand(1, properties, options)

      namespace ->
        "config #{inspect app_name}, #{inspect namespace},\n" <>
        expand(1, properties, options)
    end
  end

  def gen_config_code(namespace, app_name, properties, options) do
    "config #{inspect app_name}, #{inspect namespace},\n" <>
    expand(1, properties, options)
  end

  ##
  # Auxiliary function for gen_config_code/4 for expanding properties
  # recursively.
  @doc false
  @spec expand(
    indent :: integer(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: binary()
  def expand(indent, [property], options) do
    with nil <- get_default(options) do
      type = get_type(options)
      "#{String.duplicate("  ", indent)}" <>
      "#{property}: #{type}()"
    else
      value ->
        "#{String.duplicate("  ", indent)}" <>
        "#{property}: #{type?(value)}() # Defaults to #{inspect value}"
    end
  end

  def expand(indent, [property | properties], options) do
    "#{String.duplicate("  ", indent)}" <>
    "#{property}: [\n" <>
    expand(indent + 1, properties, options) <>
    "\n#{String.duplicate("  ", indent)}]"
  end

  ##############################
  # Environment variable getters

  ##
  # Gets the environment variable value using a state machine.
  @doc false
  @spec get_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def get_env(namespace, app_name, property, options)
      when is_atom(property) do
    get_env(namespace, app_name, [property], options)
  end

  def get_env(namespace, app_name, properties, options)
        when is_list(properties) do
    fsm_entry(namespace, app_name, properties, options)
  end

  ##
  # Gets the fresh value of a variable.
  @doc false
  @spec reload(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def reload(namespace, app_name, property, options) when is_atom(property) do
    reload(namespace, app_name, [property], options)
  end

  def reload(namespace, app_name, properties, options) do
    if cached?(options) do
      key = gen_key(namespace, app_name, properties, options)
      delete(key)
    end
    get_env(namespace, app_name, properties, options)
  end

  ###############
  # State machine

  ##
  # Entry point for the FSM.
  @doc false
  @spec fsm_entry(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def fsm_entry(namespace, app_name, properties, options) do
    if cached?(options) do
      get_cached(namespace, app_name, properties, options)
    else
      get_system(namespace, app_name, properties, options)
    end
  end

  ##
  # Tries to retrieve the cached value for the variable.
  @doc false
  @spec get_cached(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def get_cached(namespace, app_name, properties, options) do
    key = gen_key(namespace, app_name, properties, options)

    with {:error, _} <- retrieve(key),
         {:ok, value} <- get_system(namespace, app_name, properties, options),
         :ok <- store(key, value) do
      {:ok, value}
    end
  end

  ##
  # Gets the OS environment variable value if available or not skipped.
  @doc false
  @spec get_system(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def get_system(namespace, app_name, properties, options) do
    with false <- skip?(:system, options),
         value when not is_nil(value) <-
           get_system_env(namespace, app_name, properties, options) do
      {:ok, value}
    else
      _ ->
        get_config(namespace, app_name, properties, options)
    end
  end

  ##
  # Gets the `Mix` config variable value if available or not skipped.
  @doc false
  @spec get_config(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def get_config(namespace, app_name, properties, options) do
    with false <- skip?(:config, options),
         value when not is_nil(value) <-
           get_config_env(namespace, app_name, properties, options) do
      {:ok, value}
    else
      _ ->
        get_default(namespace, app_name, properties, options)
    end
  end

  ##
  # Gets the default value if present.
  @doc false
  @spec get_default(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: {:ok, term()} | {:error, term()}
  def get_default(namespace, app_name, properties, options) do
    with value when not is_nil(value) <- get_default(options) do
      {:ok, value}
    else
      _ ->
        if required?(options) do
          name = gen_env_var(namespace, app_name, properties, options)
          {:error, "#{name} variable is undefined."}
        else
          {:ok, nil}
        end
    end
  end

  ###############
  # Cache helpers

  # Retrieves the value of a `key` from a `cache`.
  @doc false
  @spec retrieve(
    key :: term()
  ) :: {:ok, term()} | {:error, term()}
  def retrieve(key) do
    case :ets.lookup(@cache, key) do
      [{^key, value} | _] ->
        {:ok, value}
      _ ->
        {:error, "Not found"}
    end
  end

  ##
  # Stores a `value` for a `key` in a `cache`.
  @doc false
  @spec store(
    key :: term(),
    value :: term()
  ) :: :ok
  def store(key, value) do
    :ets.insert(@cache, {key, value})
    :ok
  end

  ##
  # Deletes a key from the cache.
  @doc false
  @spec delete(key :: term()) :: :ok
  def delete(key) do
    :ets.delete(@cache, key)
    :ok
  end

  ##
  # Generates the key for the cache.
  @doc false
  @spec gen_key(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: term()
  def gen_key(namespace, app_name, properties, options) do
    :erlang.phash2({namespace, app_name, properties, options})
  end

  #################################
  # OS environment variable helpers

  ##
  # Gets the OS environment variable value and casts it to the correct type.
  @doc false
  @spec get_system_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: term()
  def get_system_env(namespace, app_name, properties, options) do
    name = gen_env_var(namespace, app_name, properties, options)
    with value when not is_nil(value) <- System.get_env(name) do
      cast(name, value, options)
    end
  end

  ##
  # Generates the name of the OS environment variable.
  @doc false
  @spec gen_env_var(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: binary()
  def gen_env_var(namespace, app_name, properties, options) do
    with nil <- get_alias(options) do
      namespace = gen_namespace(namespace || get_namespace(options))
      app_name = gen_app_name(app_name)
      property = gen_property(properties)

      base = "#{app_name}_#{property}"

      if namespace == "", do: base, else: "#{namespace}_#{base}"
    end
  end

  ##
  # Generates the namespace of the OS environment variable.
  @doc false
  @spec gen_namespace(namespace :: atom()) :: binary()
  def gen_namespace(nil) do
    ""
  end
  def gen_namespace(namespace) when is_atom(namespace) do
    namespace
    |> Module.split()
    |> Stream.map(&String.upcase/1)
    |> Enum.join("_")
  end

  ##
  # Generates the application name for the OS environment variable.
  @doc false
  @spec gen_app_name(app_name :: atom()) :: binary()
  def gen_app_name(app_name) when is_atom(app_name) do
    app_name
    |> Atom.to_string()
    |> String.upcase()
  end

  ##
  # Generates the property name for the OS environment variable.
  @doc false
  @spec gen_property(properties :: [atom()]) :: binary()
  def gen_property(properties) when is_list(properties) do
    properties
    |> Stream.map(&Atom.to_string/1)
    |> Stream.map(&String.upcase/1)
    |> Enum.join("_")
  end

  ##
  # Casts the value to the correct type.
  @doc false
  @spec cast(
    var_name :: binary(),
    value :: term(),
    options :: Keyword.t()
  ) :: term()
  def cast(var_name, value, options) do
    type =
      with nil <- get_default(options) do
        get_type(options)
      else
        default ->
          get_type(options) || type?(default)
      end
    do_cast(var_name, value, type)
  end

  ##
  # Checks the type of a value.
  @doc false
  @spec type?(value :: term()) :: atom()
  def type?(nil), do: nil
  def type?(value) when is_binary(value), do: :binary
  def type?(value) when is_integer(value), do: :integer
  def type?(value) when is_float(value), do: :float
  def type?(value) when is_boolean(value), do: :boolean
  def type?(value) when is_atom(value), do: :atom
  def type?(_), do: nil

  ##
  # Casts a value to the correct type.
  @doc false
  @spec do_cast(
    var_name :: binary(),
    value :: term(),
    type :: atom()
  ) :: term()
  def do_cast(var_name, value, :integer) do
    case Integer.parse(value) do
      {value, ""} ->
        value
      _ ->
        fail_cast(var_name, :integer, value)
    end
  end

  def do_cast(var_name, value, :float) do
    case Float.parse(value) do
      {value, ""} ->
        value
      _ ->
        fail_cast(var_name, :float, value)
    end
  end

  def do_cast(var_name, value, :boolean) do
    case String.upcase(value) do
      "TRUE" ->
        true
      "FALSE" ->
        false
      _ ->
        fail_cast(var_name, :boolean, value)
    end
  end

  def do_cast(_var_name, value, :atom) do
    String.to_atom(value)
  end

  def do_cast(_var_name, value, :binary) do
    value
  end

  def do_cast(var_name, value, {module, function}) do
    with {:ok, new_value} <- module.function(value) do
      new_value
    else
      {:error, error} ->
        Logger.warn(fn -> IO.inspect(error) end)
        fail_cast(var_name, function, value)
    end
  end

  ##
  # Prints a warning when the cast failed.
  @doc false
  @spec fail_cast(
    var_name :: binary(),
    type :: atom(),
    value :: term()
  ):: nil
  def fail_cast(var_name, type, value) do
    Logger.warn(fn ->
      "OS variable #{var_name} couldn't be cast to #{type} " <>
      "[value: #{inspect value}]"
    end)
    nil
  end

  ##########################################
  # Application environment variable helpers

  ##
  # Gets the `Mix` config variable value.
  @doc false
  @spec get_config_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: term()
  def get_config_env(namespace, app_name, properties, options) do
    namespace = namespace || get_namespace(options)
    get_config_env(namespace, app_name, properties)
  end

  @doc false
  @spec get_config_env(
    namespace:: atom(),
    app_name :: atom(),
    properties :: [atom()]
  ) :: term()
  def get_config_env(nil, app_name, [property | properties]) do
    value = Application.get_env(app_name, property)
    get_config_env(value, properties)
  end

  def get_config_env(namespace, app_name, properties) do
    value = Application.get_env(app_name, namespace)
    get_config_env(value, properties)
  end

  @doc false
  @spec get_config_env(
    value :: term(),
    properties :: [atom()]
  ) :: term()
  def get_config_env(value, []) do
    value
  end

  def get_config_env(value, [property | properties]) when is_list(value) do
    new_value = Keyword.get(value, property, nil)
    get_config_env(new_value, properties)
  end

  def get_config_env(_, _) do
    nil
  end
end
