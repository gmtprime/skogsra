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

  You would create a settings module and define the e.g:

  ```elixir
  defmodule MyApp.Settings do
    use Skogsra

    system_env :some_service_port,
      default: 4000

    app_env :some_service_hostname, :my_app, :hostname,
      domain: MyApp.Repo,
      default: "localhost"
  end
  ```

  and you would use it in a module as follows:

  ```
  defmodule MyApp.SomeModule do
    alias MyApp.Setting

    (...)

    def connect do
      hostname = Settings.some_service_hostname()
      port = Settings.some_service_port()

      SomeService.connect(hostname, port)
    end

    (...)
  end
  ```

  ### Example Explanation

  The module `MyApp.Settings` will have two functions e.g:

    * `some_service_port/0`: Returns the port as an integer. Calling this
      function is roughly equivalent to the following code (without the automatic
      type casting):

      ```
      System.get_env("SOME_SERVICE_PORT") || 4000
      ```

    * `some_service_hostname/0`: Returns the hostname as a binary. Calling this
      function is roughly equivalent to the following code (without the automatic
      type casting):

      ```
      case System.get_env("SOME_SERVICE_HOSTNAME") do
        nil ->
          :my_app
          |> Application.get_env(MyApp.Domain, [])
          |> Keyword.get(:hostname, "localhost")
        value ->
          value
      end
      ```

  Things to note:
    1. The functions have the same name as the OS environment variable, but in
      lower case.
    2. The functions infer the type from the `default` value. If no default value
      is provided, it will be casted as binary by default.
    3. Both functions try to retrieve and cast the value of an OS environment
      variable, but the one declared with `app_env` searches for `:my_app`
      configuration if the OS environment variable is empty:

      ```
      config :my_app, MyApp.Domain,
        hostname: "some_hostname"
      ```

  If the default value is not present, Skogsra cannot infer the type, unless the
  type is set with the option `type`. The possible values for `type` are
  `:integer`, `:float`, `:boolean`, `:atom` and `:binary`.

  ## Recommended Usage

  The recommended way of using this project is to define a `.env` file in the
  root of your project with the variables that you want to define e.g:

  ```
  export SOME_SERVICE_PORT=1234
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

    if [ -r "$env_file" ]
    then
      if [ -z "$LAST_ENV" ] && [ -r "$LAST_ENV" ]
      then
        `cat $LAST_ENV | sed -e 's/^export \([0-9a-zA-Z\_]*\)=.*$/unset \1/'`
        echo -e "\e[32mUnloaded ENV VARS defined in \"$LAST_ENV\"\e[0m"
      fi
      export LAST_ENV="$env_file"
      source $LAST_ENV
      echo -e "\e[32mLoaded \"$LAST_ENV\"\e[0m"
    fi
  }

  chpwd_functions=(${chpwd_functions[@]} "auto_env_on_chpwd")

  if [ -n "$TMUX" ]; then
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

  /home/alex/my_app $ echo "$SOME_SERVICE_PORT"
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

  Calling `Settings.foo/0` with a domain set is equivalent to:

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
