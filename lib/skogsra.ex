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
  def get_env(namespace, app_name, property, options) when is_atom(property) do
    get_env(namespace, app_name, [property], options)
  end
  def get_env(namespace, app_name, properties, options) when is_list(properties) do

  end

  #################################
  # OS environment variable helpers

  @doc false
  def get_system_env(namespace, app_name, properties, options) do
    name = gen_env_var(namespace, app_name, properties, options)
    value = System.get_env(name)
    if not is_nil(value), do: cast(value, options), else: value
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
      base = "#{gen_app_name(app_name)}_#{gen_property(properties)}"

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

  @doc """
  Gets the OS environment variable by its `name` and cast it the the type of
  the `default` value. If no `default` value is provided, returns a string.
  If the OS environment variable is not found, returns the `default` value.
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
  """
  @spec get_env_as(atom(), binary()) :: term()
  @spec get_env_as(atom(), binary(), term()) :: term()
  def get_env_as(type, name, default \\ nil) when is_binary(name) do
    default = cast_default(default, type)
    with {:ok, value} <- do_get_env_as(type, name, default) do
      value
    else
      {:error, message} ->
        Logger.warn(fn ->
          "Failed to get environment variable due to #{inspect message}"
        end)
        default
    end
  end

  @doc """
  Gets the OS environment variable by its name if present in the option
  `:name`. If it's not found, attempts to get the application configuration
  option by the `app` name and the option `key`. Optionally receives a
  `Keyword` list of `options`

  i.e:
    - `:name` - Name of the OS environment variable. By default is `""`.
    - `:default` - Default value in case the OS environment variable and the
    application configuration option don't exist. By default is `nil`.
    - `:type` - The type of the OS environment variable. By default is the type
    of the default value. If there is no default value, the default type is
    `binary`. The available types are `:binary`, `:integer`, `:float`,
    `:boolean` and `:atom`.
    - `:domain` - The `key` to search in the configuration file e.g in:
      ```elixir
      config :my_app, MyApp.Repo,
        hostname: "localhost",
        (...)
      ```
    the domain would be `MyApp.Repo`. By default, there is no domain. If the
    domain is a list of atoms forces the algorithm to go recursively in the
    structure to find the key.

  e.g:

  ```elixir
  defmodule MyApp do
    def get_hostname do
      Skogsra.get_app_env(:my_app, :hostname, domain: MyApp.Repo, name: "SOME_SERVICE_HOSTNAME")
    end
  end
  ```
  """
  @spec get_app_env(atom(), atom()) :: term()
  @spec get_app_env(atom(), atom(), list()) :: term()
  def get_app_env(app, key, options \\ []) do
    name = Keyword.get(options, :name, "")
    default = Keyword.get(options, :default, nil)
    type = Keyword.get(options, :type, type?(default))
    with default = cast_default(default, type),
         value when is_nil(value) <- get_env_as(type, name),
         domain = Keyword.get(options, :domain),
         {:ok, value} <- do_get_app_env(type, app, domain, key, default) do
      value
    else
      {:error, _} ->
        default
      value ->
        value
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
      def unquote(name)() do
        unquote(value)
      end
    end
  end

  @doc false
  def runtime_app_env(name, app, key, opts) do
    env_name = name |> Atom.to_string() |> String.upcase()
    quote do
      def unquote(name)() do
        Skogsra.get_app_env(
          unquote(app),
          unquote(key),
          [{:name, unquote(env_name)} | unquote(opts)]
        )
      end
    end
  end

  @doc false
  def static_app_env(name, app, key, opts) do
    env_name = name |> Atom.to_string() |> String.upcase()
    value = Skogsra.get_app_env(app, key, [{:name, env_name} | opts])
    quote do
      def unquote(name)() do
        unquote(value)
      end
    end
  end

  @doc false
  def do_get_app_env(type, app, nil, key, default) do
    value = Application.get_env(app, key, default)
    cast(value, type)
  end
  def do_get_app_env(type, app, domain, key, default) when is_atom(domain) do
    do_get_app_env(type, app, [domain], key, default)
  end
  def do_get_app_env(type, app, [domain | domains], key, default) do
    case Application.get_env(app, domain) do
      nil ->
        {:ok, default}
      opts ->
        value = do_get_app_env(opts, domains, key, default)
        cast(value, type)
    end
  end

  @doc false
  def do_get_app_env(opts, [], key, default) do
    Keyword.get(opts, key, default)
  end
  def do_get_app_env(opts, [domain | domains], key, default) do
    case Keyword.get(opts, domain) do
      nil ->
        default
      new_opts ->
        do_get_app_env(new_opts, domains, key, default)
    end
  end

  @doc false
  def do_get_env_as(type, name, default \\ nil)

  def do_get_env_as(_, "", default) do
    {:ok, default}
  end
  def do_get_env_as(type, name, default) do
    value = System.get_env(name)
    if is_nil(value) do
      {:ok, default}
    else
      cast(value, type)
    end
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
      _ ->
        nil
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
  def cast(value, _) do
    {:ok, value}
  end
end
