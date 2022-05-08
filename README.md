# Skogsrå

[![Build Status](https://travis-ci.org/gmtprime/skogsra.svg?branch=master)](https://travis-ci.org/gmtprime/skogsra) [![Hex pm](http://img.shields.io/hexpm/v/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra) [![hex.pm downloads](https://img.shields.io/hexpm/dt/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra) [![Coverage Status](https://coveralls.io/repos/github/gmtprime/skogsra/badge.svg?branch=master)](https://coveralls.io/github/gmtprime/skogsra?branch=master)

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
* Posibility to override Elixir configuration.
* Runtime reloading.
* Setting variable's values at runtime.
* Fast cached values access by using `:persistent_term` as temporal storage.
* Custom variable bindings.
* YAML and JSON configuration providers for Elixir releases.

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
   ```elixir
   config :myapp,
     hostname: "my.custom.host"
   ```
3. From the default value if it exists (In this case, it would return
   `"localhost"`).

## Available options

There are several options for configuring an environment variables:

Option          | Type                                                 | Default              | Description
:-------------- | :--------------------------------------------------- | :------------------- | :----------
`default`       | `any`                                                | `nil`                | Sets the Default value for the variable.
`type`          | [`Skogsra.Env.type()`](#types)                       | `:any`               | Sets the explicit type for the variable.
`os_env`        | `binary`                                             | autogenerated        | Overrides automatically generated OS environment variable name.
`binding_order` | [`Skogra.Env.bindings()`](#custom-variable-bindings) | `[:system, :config]` | Sets the load order for variable binding.
`binding_skip`  | [`Skogra.Env.bindings()`](#custom-variable-bindings) | `[]`                 | Which variable bindings should be skipped.
`required`      | `boolean`                                            | `false`              | Whether the variable is required or not.
`cached`        | `boolean`                                            | `true`               | Whether the variable should be cached or not.

> **IMPORTANT**: Options `skip_system: true` and `skip_config: true` have been
> deprecated in favour of `binding_skip: [:system]` and `binding_skip: [:config]`
> respectively.

Additional topics:

- [Types](#types)
- [Automatic type casting](#automatic-type-casting).
- [Explicit type casting](#explicit-type-casting).
- [Custom types](#custom-types).
- [Explicit OS environment variable names](#explicit-os-environment-variable-name).
- [Required variables](#required-variables).
- [Overriding Elixir Configuration](#overriding-elixir-configuration).
- [Caching variables](#caching-variables).
- [Handling different environments](#handling-different-environments).
- [Setting and reloading variables](#setting-and-reloading-variables).
- [Automatic docs generation](#automatic-docs-generation).
- [Automatic spec generation](#automatic-spec-generation).
- [Automatic template generation](#automatic-template.generation).
- [Custom variable bindings](#custom-variable-bindings).
- [Elixir release YAML and JSON config providers](#elixir-release-yaml-and-json-config-providers).
- [Using with Hab](#using-with-hab).
- [Installation](#installation).

## Types

Skogsrå implements several built-in types. Some of them can be
[inferred from the default value](#automatic-type-casting) while others must be
[set explicitly](#explicit-type-casting):

Type                          | Can be inferred? | Description
:---------------------------- | :--------------- | :---------------
`:any`                        | Yes              | Any Elixir term.
`:binary`                     | Yes              | A string e.g. `"localhost"`.
`:integer`                    | Yes              | An integer e.g. `42`.
`:neg_integer`                | No               | A negative integer.
`:non_neg_integer`            | No               | A non negative integer.
`:pos_integer`                | No               | A positive integer.
`:float`                      | Yes              | A float e.g. `42.0`.
`:boolean`                    | Yes              | A boolean e.g. `false`.
`:atom`                       | Yes              | An atom e.g. `:ok`.
`:module`                     | No               | An existent module e.g. `Enum`.
`:unsafe_module`              | No               | A module e.g. `SomeModule`.
`Skogsra.Type` implementation | No               | See [Custom types](#custom-types) section.

## Automatic type casting

If the `default` value is set (and no explicit `type` is found), the variable
value will be casted as the same type of the default value. For this to work,
the default value should be of the following types:

- `:any`
- `:binary`
- `:integer`
- `:float`
- `:boolean`
- `:atom`

e.g. in the following example, the value will be casted to `:atom`
automatically:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My environment"
  app_env :my_environment, :myapp, :environment,
    default: :prod
end
```

If either of the system OS or the application environment variables are defined,
Skogsrå will try to cast their values to the default value's type which it
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

A type can be explicitly set. The available types are the following:

 - `:any` (default).
 - `:binary`.
 - `:integer`.
 - `:neg_integer`.
 - `:non_neg_integer`.
 - `:pos_integer`.
 - `:float`.
 - `:boolean`.
 - `:atom`.
 - `:module` (modules loaded in the system).
 - `:unsafe_module` (modules that might or might not be loaded in the system)
 - A module name with an implementation for the behaviour `Skogsra.Type`.

e.g. in the following example, the value will be casted to `:pos_integer`
according to the variable definition:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "Port"
  app_env :my_port, :myapp, :port,
    default: 4000,
    type: :pos_integer
end
```

If either of the system OS or the application environment variables are defined,
Skogsrå will try to cast their values to a positive integer.

```elixir
iex(1)> System.get_env("MYAPP_PORT")
"42"
iex(2)> MyApp.Config.my_port()
{:ok, 42}
```

or

```elixir
iex(1)> Application.get_env(:myapp, :port)
42
iex(2)> MyApp.Config.my_port()
{:ok, 42}
```

## Custom types

Skogsrå's types can be extented by implementing `Skogra.Type` behaviour e.g. a
possible implementation for casting `"1, 2, 3, 4"` to `[integer()]` would be:

```elixir
defmodule MyList do
  use Skogsra.Type

  @impl Skogsra.Type
  def cast(value)

  def cast(value) when is_binary(value) do
    list =
      value
      |> String.split(~r/,/)
      |> Stream.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)

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

If then we define the following enviroment variable with Skogsrå:

```elixir
defmodule MyApp.Config do
  use Skogsra

  app_env :my_integers, :myapp, :integers,
    type: MyList
end
```

If either of the system OS or the application environment variables are defined,
Skogsrå will try to cast their values using our implementation e.g:

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

Though Skogsrå automatically generates the names for the OS environment
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
Skogsrå will return an error e.g:

```elixir
iex(1)> System.get_env("MYAPP_PORT")
nil
iex(2)> Application.get_env(:myapp, :port)
nil
iex(3)> MyApp.Config.my_port()
{:error, "Variable port in app myapp is undefined"}
```

The module will also provide `validate` and `validate!` functions that can be
used in your application startup phase to verify that *all* required variables
are present e.g:

```elixir
iex(1)> System.get_env("MYAPP_PORT")
nil
iex(2)> Application.get_env(:myapp, :port)
nil
iex(3)> MyApp.Config.validate!()
** (RuntimeError) Variable port in app myapp is undefined
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
   ```elixir
   config :myapp, Test,
     port: 4001
   ```
3. From the OS environment variable `$MYAPP_PORT`.
4. From the configuraton file e.g:
   ```elixir
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

While our Skogsrå module would look like:

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

## Overriding Elixir Configuration

Not all the libraries will use Skogsrå and, though is a shame, we can always
override a config value using the function `preload/0` e.g.

Let's say we have a Phoenix application and we want to configure our endpoint
with the following variables.

- The OS environment variable `PORT` for our app's HTTP port.
- The OS environment variable `SECRET_KEY_BASE` for our secret key base.

A regular Phoenix configuration will look like the following:

```elixir
use Mix.Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """


config :myapp_web, MyappWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base
```

With Skogsrå, we can reduce the config to the following:

```elixir
use Mix.Config

config :myapp_web, Myapp.Endpoint,
  http: [
    transport_options: [socket_opts: [:inet6]]
  ]
```

Then, handle our variables in our Skogsrå config module:

```elixir
defmodule MyappWeb.Config do
  use Skogsra

  @envdoc """
  App port.
  """
  app_env :port, :myapp, [:http, :port],
    os_env: "PORT",
    default: 4000

  @envdoc """
  Secret key base.
  """
  app_env :secret_key_base, :myapp, :secret_key_base,
    os_env: "SECRET_KEY_BASE",
    default: "+/JwMGGtsTVOoX5gQrCMn8aHKfKDdUK8GeAKJ2fIUabUnmWTwg+zsCy4pAOmOdTs"
end
```

And finally calling the preload function in our application init:

```elixir
defmodule MyappWeb.Application do
  use Application

  def start(_type, _args) do
    MyappWeb.Config.preload(MyappWeb.Endpoint)

    children = [
      MyappWeb.Endpoint
    ]

    ...
  end
end
```

The function `MyappWeb.Config.preload/1` will override any configuration for
`MyappWeb.Endpoint` as long as is a runtime config.

Our app now will try to get the port and secret key from the OS environment
variables first and it will fallback to the defaults.

## Caching variables

By default, Skogsrå caches the values of the variables using
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

Specs are generated following the following table:

Assuming the type is set to `:integer` explicitly (`type: :integer`) or
implicitly (`default: 4000`), the specs should follow the following table:

Required     | Has default     | Spec
:----------: | :-------------: | :----
`true`       | `true`          | `@spec my_port() :: {:ok, integer()} \| {:error, binary()}`
`true`       | `false`         | `@spec my_port() :: {:ok, integer()} \| {:error, binary()}`
`false`      | `true`          | `@spec my_port() :: {:ok, integer()} \| {:error, binary()}`
`false`      | `false`         | `@spec my_port() :: {:ok, nil \| integer()} \| {:error, binary()}`

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

  ```bat
  :: DOCS My port
  :: TYPE integer
  SET MYAPP_PORT="Elixir.Application"
  ```

## Custom variable bindings

By default, Skogsrå loads variables in the following order:

- OS environment variables or `:system`.
- Application configuratuon or `:config`.

This means that every variable has the following defaults:

- For `binding_order` is `[:system, :config]`.
- For `binding_skip` is `[]`.

These two values can be modified globally via configuration e.g:

- For globally changing the variable binding order:

   ```elixir
   config :skogsra,
     binding_order: [:config, :system]
   ```

- For globally skipping `:system`:

   ```elixir
   config :skogsra,
     binding_skip: [:system]
   ```

Or be modified per `app_env` e.g:

- For changing `MyApp.Config.my_port/0` binding order:

   ```elixir
   defmodule MyApp.Config do
     use Skogsra

     @envdoc "My port"
     app_env :my_port, :myapp, :port,
       binding_order: [:config, :system]
   end
   ```

- For skipping `:system` in `MyApp.Config.my_port/0`:

   ```elixir
   defmodule MyApp.Config do
     use Skogsra

     @envdoc "My port"
     app_env :my_port, :myapp, :port,
       binding_skip: [:system]
   end
   ```

Additionally, we can create new variable bindings by implementing
`Skogsra.Binding` behaviour e.g. an implementation for loading JSON
configuration files would be:

```elixir
defmodule MyApp.Json do
  use Skogsra.Binding

  alias Skogsra.Env

  @impl true
  def init(%Env{} = env) do
    options = Env.extra_options(env)

    case options[:config_path] do
      nil ->
        {:error, "JSON config path not specified"}

      path ->
        load(path)
    end
  end

  @impl true
  def get_env(%Env{} = env, config) when is_map(config) do
    name = Env.os_env(env)
    value = config[name]

    {:ok, value}
  end

  # Helpers

  # Loads JSON once and caches it in a :persistent_term using the path
  # as the key.
  @spec load(binary()) :: {:ok, map()} | {:error, term()}
  defp load(path) do
    with nil <- :persistent_term.get(path, nil),
         {:ok, contents} <- File.read(path),
         {:ok, config} <- Jason.decode(contents),
         :ok <- :persistent_term.put(path, config) do
      {:ok, config}
    else
      {:error, reason} ->
        {:error, "Cannot load #{path} due to #{inspect(reason)}"}

      config ->
        {:ok, config}
    end
  end
end
```

The previous implementation expects variables to be named the same as the
OS environment variables e.g:

```json
{
  "MYAPP_PORT": 5000
}
```

Then our variable declaration would look something like the following:

```elixir
defmodule MyApp.Config do
  use Skogsra

  @envdoc "My port"
  app_env :my_port, :myapp, :port,
    binding_order: [:system, :config, MyApp.Json],
    config_path: "#{Path.cwd!()}/priv/config.json",
    default: 4000
end
```

If no `:system` or `:config` is found, it will try to load the variable from
the JSON file e.g:

```elixir
iex> MyApp.Config.port()
{:ok, 5000}
```

> **Note**: The same casting rules apply for all bindings.

## Elixir release YAML and JSON config providers

Skogsrå includes two simple configuration providers compatible with
`mix release` for Elixir ≥ 1.9:

- YAML configuration provider:

   ```yaml
   - app: "my_app"              # Name of the application.
     module: "MyApp.Repo"       # Optional module/namespace.
     config:                    # Actual configuration.
       database: "my_app_db"
       username: "postgres"
       password: "postgres"
       hostname: "localhost"
       port: 5432
   ```

- JSON configuration provider:

   ```json
   [
     {
       "app": "my_app",
       "module": "MyApp.Repo",
       "config": {
         "database": "my_app_db",
         "username": "postgres",
         "password": "postgres",
         "hostname": "localhost",
         "port": 5432
       }
     }
   ]
   ```

Both configurations would be equivalent to:

```elixir
config :my_app, MyApp.Repo,
  database: "my_App_db",
  username: "postgres"
  password: "postgres"
  hostname: "localhost"
  port: 5432
```

For using these config providers, just add the following to your release
configuration:

- For YAML configurations:

   ```elixir
   config_providers: [{Skogsra.Provider.Yaml, ["/path/to/config/file.yml"]}]
   ```

- For JSON configurations:

   ```elixir
   config_providers: [{Skogsra.Provider.Json, ["/path/to/config/file.json"]}]
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
in `mix.exs` (Elixir ≥ 1.9 and Erlang ≥ 22):

```elixir
def deps do
  [
    {:skogsra, "~> 2.4"}
  ]
end
```

If you need YAML config provider support, add the following:

```elixir
def deps do
  [
    {:skogsra, "~> 2.4"},
    {:yamerl, "~> 0.10"}
  ]
end
```

If you need JSON config provider support, add  the following:

```elixir
def deps do
  [
    {:skogsra, "~> 2.4"},
    {:jason, "~> 1.3"}
  ]
end
```

## Author

Alexander de Sousa.

## License

_Skogsrå_ is released under the MIT License. See the LICENSE file for further
details.
