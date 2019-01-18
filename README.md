# Skogsra

[![Build Status](https://travis-ci.org/gmtprime/skogsra.svg?branch=master)](https://travis-ci.org/gmtprime/skogsra) [![Hex pm](http://img.shields.io/hexpm/v/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra) [![hex.pm downloads](https://img.shields.io/hexpm/dt/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra)

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
it as first parameter.

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

## Installation

The package can be installed by adding `skogsra` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:skogsra, "~> 1.0"}]
end
```

## Author

Alexander de Sousa.

## License

`Skogsra` is released under the MIT License. See the LICENSE file for further
details.
