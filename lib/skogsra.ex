defmodule Skogsra do
  @moduledoc """

  > The _Skogsrå_ was a mythical creature of the forest that appears in the form
  > of a small, beautiful woman with a seemingly friendly temperament. However,
  > those who are enticed into following her into the forest are never seen
  > again.

  This library attempts to improve the use of OS environment variables for
  application configuration:

    * Automatic type casting of values.
    * Options documentation.
    * Variables defaults.

  ## Small Example

  You would create a settings module e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    app_env :my_hostname, :myapp, :hostname,
      default: "localhost"

    app_env :my_port, :myservice, :port
      default: 4000,
      skip_config: true
  end
  ```

  This module will generate in essence two functions:
  - `my_hostname/0` - it will look for the OS environment variable
    `$MYAPP_HOSTNAME` or, if it's not set, it will look for the value set in the
    configuration e.g:
    ```
    config :myapp,
      hostname: "my.custom.host"
    ```
    If still the configuration is not set, it will return the default value
    `"localhost"`.
  - `my_port/0` - it will look for the OS environment variable
    `$MYSERVICE_PORT` and cast it to integer or, if it's not set, it will return
    the default `4000`.

  Then using this functions is as simple as calling them in your module e.g:

  ```
  defmodule MyApp.SomeModule do
    alias MyApp.Settings

    (...)

    def connect do
      hostname = Settings.my_hostname()
      port = Settings.my_port()

      SomeService.connect(hostname, port)
    end

    (...)
  end
  ```

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
      UNSET=$(cat $LAST_ENV | sed -e 's/^export \([0-9a-zA-Z\_]*\)=.*$/unset \1/')
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
  is not present, defaults to binary.
  - `alias` - Alias for the variable in the OS. If the alias is `nil` will
  use the default name. This option is ignoredif the option `skip_system` is
  `true` (default is `false`).
  - `namespace` - Namespace of the variable.
  - `skip_system` - If `true`, doesn't look for the variable value in the
  system. Defaults to `false`.
  - `skip_config` - If `true`, doesn't look for the variable value in the
  configuration. Defaults to `false`.
  - `error_when_nil` - Errors when the value is `nil`. Defaults to `false`.

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
      def unquote(function_name)(namespace \\ nil) do
        app_name = unquote(app_name)
        properties = unquote(properties)
        options = unquote(options)

        Skogsra.get_env(app_name, properties, options)
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
        app_name = unquote(app_name)
        properties = unquote(properties)
        options = unquote(options)

        case Skogsra.get_env(namespace, app_name, properties, options) do
          {:ok, value} ->
            value

          {:error, error} ->
            Logger.error(fn -> IO.inspect(error) end)
        end
      end
    end
  end

  @doc false
  @spec get_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: atom() | [atom()],
    options :: Keyword.t()
  ) :: term()
  def get_env(namespace, app_name, property, options)
      when is_atom(property) do
    get_env(namespace, app_name, [property], options)
  end
  def get_env(namespace, app_name, properties, options)
      when is_list(properties) do
    fsm_entry(namespace, app_name, properties, options)
  end

  ###############
  # State machine

  @doc false
  def fsm_entry(namespace, app_name, properties, options) do
    get_system(namespace, app_name, properties, options)
  end

  @doc false
  def get_system(namespace, app_name, properties, options) do
    with false <- Keyword.get(options, :skip_system, false),
         value when not is_nil(value) <-
           get_system_env(namespace, app_name, properties, options) do
      {:ok, value}
    else
      _ ->
        get_config(namespace, app_name, properties, options)
    end
  end

  @doc false
  def get_config(namespace, app_name, properties, options) do
    with false <- Keyword.get(options, :skip_config, false),
         value when not is_nil(value) <-
           get_config_env(namespace, app_name, properties, options) do
      {:ok, value}
    else
      _ ->
        get_default(namespace, app_name, properties, options)
    end
  end

  @doc false
  def get_default(namespace, app_name, properties, options) do
    with value when not is_nil(value) <- options[:default] do
      {:ok, value}
    else
      _ ->
        if Keyword.get(options, :error_when_nil, false) do
          name = gen_env_var(namespace, app_name, properties, options)
          {:error, "#{name} variable is undefined."}
        else
          {:ok, nil}
        end
    end
  end

  #################################
  # OS environment variable helpers

  @doc false
  @spec gen_env_var(
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

  @doc false
  @spec gen_env_var(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: binary()
  def gen_env_var(namespace, app_name, properties, options) do
    with nil <- options[:alias] do
      namespace = gen_namespace(namespace || options[:namespace])
      app_name = gen_app_name(app_name)
      property = gen_property(properties)

      base = "#{app_name}_#{property}"

      if namespace == "", do: base, else: "#{namespace}_#{base}"
    end
  end

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

  @doc false
  @spec gen_app_name(app_name :: atom()) :: binary()
  def gen_app_name(app_name) when is_atom(app_name) do
    app_name
    |> Atom.to_string()
    |> String.upcase()
  end

  @doc false
  @spec gen_property(properties :: [atom()]) :: binary()
  def gen_property(properties) when is_list(properties) do
    properties
    |> Stream.map(&Atom.to_string/1)
    |> Stream.map(&String.upcase/1)
    |> Enum.join("_")
  end

  @doc false
  @spec cast(
    var_name :: binary(),
    value :: term(),
    options :: Keyword.t()
  ) :: term()
  def cast(var_name, value, options) do
    default = Keyword.get(options, :default, "")
    type = Keyword.get(options, :type, type?(default))
    do_cast(var_name, value, type)
  end

  @doc false
  @spec type?(value :: term()) :: atom()
  def type?(nil), do: nil
  def type?(value) when is_binary(value), do: :binary
  def type?(value) when is_integer(value), do: :integer
  def type?(value) when is_float(value), do: :float
  def type?(value) when is_boolean(value), do: :boolean
  def type?(value) when is_atom(value), do: :atom
  def type?(_), do: nil

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

  def do_cast(_var_name, value, _) do
    value
  end

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

  @doc false
  @spec get_config_env(
    namespace :: atom(),
    app_name :: atom(),
    properties :: [atom()],
    options :: Keyword.t()
  ) :: term()
  def get_config_env(namespace, app_name, properties, options) do
    namespace = namespace || options[:namespace]
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
