# Skogsra

[![Build Status](https://travis-ci.org/gmtprime/skogsra.svg?branch=master)](https://travis-ci.org/gmtprime/skogsra) [![Hex pm](http://img.shields.io/hexpm/v/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra) [![hex.pm downloads](https://img.shields.io/hexpm/dt/skogsra.svg?style=flat)](https://hex.pm/packages/skogsra)

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
    domain: MyApp.Domain,
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

## Installation

The package can be installed by adding `skogsra` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:skogsra, "~> 0.2"}]
end
```

## Author

Alexander de Sousa.

## License

`Skogsra` is released under the MIT License. See the LICENSE file for further
details.
