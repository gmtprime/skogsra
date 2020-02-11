# Skogsrå

[![Build Status](https://travis-ci.org/gmtprime/skogsra.svg?branch=master)](https://travis-ci.org/gmtprime/skogsra) [![Hex pm](http://img.shields.io/hexpm/v/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra) [![hex.pm downloads](https://img.shields.io/hexpm/dt/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra)

> The _Skogsrå_ was a mythical creature of the forest that appears in the form
> of a small, beautiful woman with a seemingly friendly temperament. However,
> those who are enticed into following her into the forest are never seen
> again.

This library attempts to improve the use of OS environment variables for
application configuration:

* Variable defaults.
* Automatic type casting of values.
* Automatic docs and spec generation.
* OS environment template generation.
* Runtime reloading.
* Setting variable's values at runtime.
* Fast cached values access by using `:persistent_term` as temporal storage.
* YAML configuration provider for Elixir releases.

## Small example

You would create a config module e.g:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My hostname"
  app_env :my_hostname, :myapp, :hostname,
    default: "localhost"
end
```

Calling `MyApp.Config.my_hostname()` will retrieve the value for the
hostname in the following order:

1. From the OS environment variable `$MYAPP_HOSTNAME` (can be overriden by the
   option `os_env`).
2. From the configuration file e.g:
     ```
     config :myapp,
       hostname: "my.custom.host"
     ```
3. From the default value if it exists (In this case, it would return
   `"localhost"`).

## Available options

There are several options for configuring an environment variables:

Option        | Type                 | Default       | Description
:------------ | :------------------- | :------------ | :----------
`default`     | `any`                | `nil`         | Sets the Default value for the variable.
`type`        | `Skogsra.Env.type()` | `:binary`     | Sets the explicit type for the variable.
`os_env`      | `binary`             | autogenerated | Overrides automatically generated OS environment variable name.
`skip_system` | `boolean`            | `false`       | Whether it should skip looking for a value in the OS or not.
`skip_config` | `boolean`            | `false`       | Whether it should skip looking for a value in the application config or not.
`required`    | `boolean`            | `false`       | Whether the variable is required or not.
`cached`      | `boolean`            | `true`        | Whether the variable should be cached or not.

Additional topics:

- [Automatic type casting](#automatic-type-casting).
- [Explicit type casting](#explicit-type-casting).
- [Explicit OS environment variable names](#explicit-os-environment-variable-name).
- [Required variables](#required-variables).
- [Caching variables](#caching-variables).
- [Handling different environments](#handling-different-environments).
- [Setting and reloading variables](#setting-and-reloading-variables).
- [Automatic docs generation](#automatic-docs-generation).
- [Automatic spec generation](#automatic-spec-generation).
- [Automatic template generation](#automatic-template.generation).
- [YAML Config Provider](#yaml-config-provider).
- [Using with Hab](#using-with-hab).
- [Installation](#installation).

## Automatic type casting

If the `default` value is set (and no explicit `type` is found), the variable
value will be casted as the same type of the default value. For this to work,
the default value should be of the following types:

- `:binary`
- `:integer`
- `:float`.
- `:boolean`
- `:atom`

e.g. in the following example, the value will be casted to `:atom`
automatically:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My environment"
  app_env :my_environmen, :myapp, :environment,
    default: :prod
end
```

If either of the system OS or the application environment variables are defined,
`Skogsra` will try to cast their values to the default value's type which it
`atom` e.g:

```elixir
iex(1)> System.get_env("MYAPP_ENVIRONMENT")
"staging"
iex(2)> MyApp.Config.my_environment()
{:ok, :staging}
```

or

```elixir
iex(1)> Application.get_env(:myapp, :environment)
"staging"
iex(2)> MyApp.Config.my_environment()
{:ok, :staging}
```

> **Note**: If the variable is already of the desired type, it won't be casted.

## Explicit type casting

A type can be explicitly set. The available types are:
 - `:binary` (default).
 - `:integer`.
 - `:float`.
 - `:boolean`.
 - `:atom`.
 - `:module` (modules loaded in the system).
 - `:unsafe_module` (modules that might or might not be loaded in the system)
 - A module name with an implementation for the behaviour `Skogsra.Type`.

e.g. a possible implementation for casting `"1, 2, 3, 4"` to `[integer()]`
would be:

```elixir
defmodule MyList do
  use Skogsra.Type

  def cast(value) when is_binary(value) do
    list =
      value
      |> String.split(~r/,/)
      |> Stream.map(&String.trim/1)
      |> Enum.map(String.to_integer/1)
    {:ok, list}
  end

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_integer/1), do: {:ok, value}, else: :error
  end

  def cast(_) do
    :error
  end
end
```

If then we define the following enviroment variable with `Skogsra`:

```elixir
defmodule MyApp.Config do
  use Skogsra

  app_env :my_integers, :myapp, :integers,
    type: MyList
end
```

If either of the system OS or the application environment variables are defined,
`Skogsra` will try to cast their values using our implementation e.g:

```elixir
iex(1)> System.get_env("MYAPP_INTEGERS")
"1, 2, 3"
iex(2)> MyApp.Config.my_integers()
{:ok, [1, 2, 3]}
```

or

```elixir
iex(1)> Application.get_env(:myapp, :integers)
[1, 2, 3]
iex(2)> MyApp.Config.my_integers()
{:ok, [1, 2, 3]}
```

> **Important**: The `default` value is not cast according to `type`.

## Explicit OS environment variable names

Though `Skogsra` automatically generates the names for the OS environment
variables, they can be overriden by using the option `os_env` e.g:

```elixir
defmodule MyApp.Config do
  use Skogsra

  app_env :db_hostname, :myapp, [:postgres, :hostname],
    os_env: "PGHOST"
end
```

This will override the value `$MYAPP_POSTGRES_HOSTNAME` with `$PGHOST` e.g:

```elixir
iex(1)> System.get_env("MYAPP_POSTGRES_HOSTNAME")
"unreachable"
iex(2)> System.get_env("PGHOST")
"reachable"
iex(3)> MyApp.Config.db_hostname()
{:ok, "reachable"}
```

## Required variables

It is possible to set a environment variable as required with the `required`
option e.g:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    required: true
end
```

If none of the system OS or the application environment variables are defined,
`Skogsra` will return an error e.g:

```elixir
iex(1)> System.get_env("MYAPP_PORT")
nil
iex(2)> Application.get_env(:myapp, :port)
nil
iex(2)> MyApp.Config.my_port()
{:error, "Variable port in app myapp is undefined"}
```

## Handling different environments

If it's necessary to keep several environments, it's possible to use a
`namespace` e.g. given the following variable:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    default: 4000
end
```

Calling `MyApp.Config.my_port(Test)` will retrieve the value for the hostname
in the following order:

1. From the OS environment variable `$TEST_MYAPP_PORT`.
2. From the configuration file e.g:
    ```
    config :myapp, Test,
      port: 4001
    ```
3. From the OS environment variable `$MYAPP_PORT`.
4. From the configuraton file e.g:
    ```
    config :myapp,
      port: 80
    ```
5. From the default value if it exists. In our example, `4000`.

The ability of loading different environments allows us to do the following
with our configuration file:

```elixir
# file: config/config.exs
use Mix.Config

config :myapp, Prod
  port: 80

config :myapp, Test,
  port: 4001

config :myapp,
  port: 4000
```

While our `Skogsra` module would look like:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "Application environment"
  app_env :env, :myapp, :environment,
    type: :unsafe_module

  @envdoc "Application port"
  app_env :port, :myapp, :port,
    default: 4000
end
```

The we can retrieve the values depending on the value of the OS environment
variable `$MYAPP_ENVIRONMENT`:

```elixir
...
with {:ok, env} <- MyApp.Config.env(),
     {:ok, port} <- Myapp.Config.port(env) do
  ... do something with the port ...
end
...
```

## Caching variables

By default, `Skogsra` caches the values of the variables using
`:persistent_term` Erlang module. This makes reads very fast, but **writes are
very slow**.

So avoid setting or reloading values to avoid performance issues (see
[Setting and reloading variables](#setting-and-reloading-variables)).

If you don't want to cache the values, you can set it to `false`:

```elixir
defmodule MyApp.Config do
  use Skogsra

  app_env :value, :myapp, :value,
    cached: false
end
```

## Setting and reloading variables

Every variable definition will generate two additional functions for setting
and reloading the values e.g:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    default: 4000
end
```

will have the functions:

- `MyApp.Config.put_my_port/1` for setting the value of the variable at
  runtime.
- `MyApp.Config.reload_my_port/` for reloading the value of the variable at
  runtime.

## Automatic docs generation

It's possible to document a configuration variables using the module attribute
`@envdoc` e.g:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    default: 4000
end
```

Skogsra then will automatically generate instructions on how to use the
variable. This extra documentation can be disable with the following:

```elixir
config :skogsra,
  generate_docs: false
```

> **Note**: for "private" configuration variables you can use `@envdoc false`.

## Automatic spec generation

Skogsra will try to generate the appropriate spec for every function generated.
In our example, given the default value is an integer, the function spec will be
the following:

```elixir
@spec my_port() :: {:ok, integer()} | {:error, binary()}
@spec my_port(Skogsra.Env.namespace()) ::
        {:ok, integer()} | {:error, binary()}
```

> **Note**: The same applies for `my_port!/0`, `reload_my_port/0` and
> `put_my_port/1`.

## Automatic template generation

Every Skogsra module includes the functions `template/1` and `template/2` for
generating OS environment variable files e.g. continuing our example:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    default: 4000
end
```

- For Elixir releases:

  ```elixir
  iex(1)> Myapp.Config.template("env")
  :ok
  ```

  will generate the file `env` with the following contents:

  ```bash
  # DOCS My port
  # TYPE integer
  MYAPP_PORT="Elixir.Application"
  ```
- For Unix:

  ```elixir
  iex(1)> Myapp.Config.template("env", type: :unix)
  :ok
  ```

  will generate the file `env` with the following contents:

  ```bash
  # DOCS My port
  # TYPE integer
  export MYAPP_PORT='Elixir.Application'
  ```

- For Windows:

  ```elixir
  iex(1)> Myapp.Config.template("env.bat", type: :windows)
  :ok
  ```

  will generate the file `env.bat` with the following contents:

  ```bash
  :: DOCS My port
  :: TYPE integer
  SET MYAPP_PORT="Elixir.Application"
  ```

## YAML Config Provider

`Skogsra` includes a simple YAML configuration provider compatible with
`mix release` for Elixir ≥ 1.9.

The following is the supported configuration format:

```yaml
# file: /etc/my_app/config.yml
- app: "my_app"              # Name of the application.
  module: "MyApp.Repo"       # Optional module/namespace.
  config:                    # Actual configuration.
    - database: "my_app_db"
      username: "postgres"
      password: "postgres"
      hostname: "localhost"
      port: 5432
```

The previous configuration file would translate to:

```elixir
config :my_app, MyApp.Repo,
  database: "my_App_db",
  username: "postgres"
  password: "postgres"
  hostname: "localhost"
  port: 5432
```

For using this config provider, just add the following to your release
configuration:

```elixir
config_providers: [{Skogsra.Provider.Yaml, ["/path/to/config/file.yml"]}]
```

> **Note**: If the `module` you're using in you're config does not exist, then
> change it to `namespace` e.g: `namespace: "MyApp.Repo"`. Otherwise, it will
> fail loading it.

## Using with `Hab`

[_Hab_](https://github.com/alexdesousa/hab) is an
[Oh My ZSH](https://github.com/robbyrussell/oh-my-zsh) plugin for loading OS
environment variables automatically.

By default, `Hab` will try to load `.envrc` file, but it's possible to have
several of those files for different purposes e.g:

- `.envrc.prod` for production OS variables.
- `.envrc.test` for testing OS variables.
- `.envrc` for development variables.

`Hab` will load the development variables by default, but it can load the
other files using the command `hab_load <extension>` e.g. loading
`.envrc.prod` would be as follows:

```bash
~/my_project $ hab_load prod
[SUCCESS]  Loaded hab [/home/user/my_project/.envrc.prod]
```

## Installation

The package can be installed by adding `skogsra` to your list of dependencies
in `mix.exs`.

- For Elixir ≥ 1.8 and Erlang ≥ 22

  ```elixir
  def deps do
    [{:skogsra, "~> 2.1"}]
  end
  ```

- For Elixir ≥ 1.9, Erlang ≥ 22 and YAML config provider support:

  ```elixir
  def deps do
    [
      {:skogsra, "~> 2.1"},
      {:yamerl, "~> 0.7"}
    ]
  end
  ```

## Author

Alexander de Sousa.

## License

_Skogsrå_ is released under the MIT License. See the LICENSE file for further
details.
