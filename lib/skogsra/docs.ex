defmodule Skogsra.Docs do
  @moduledoc """
  This module defines the documentation generators.
  """
  alias Skogsra.Env
  alias Skogsra.System

  @typedoc """
  Custom docs.
  """
  @type docs :: nil | binary()

  @typedoc """
  Function name.
  """
  @type function_name :: atom()

  @doc """
  Generates docs for a variable given its `module`, `function_name`,
  `app_name`, `keys` to find it, `options` and custom `docs`.
  """
  @spec gen_full_docs(
          module(),
          function_name(),
          Env.app_name(),
          Env.keys(),
          Env.options(),
          docs()
        ) :: binary()
  def gen_full_docs(module, function_name, app_name, keys, options, docs)

  def gen_full_docs(module, function_name, app_name, keys, options, docs) do
    module = Macro.to_string(module)
    no_namespace = Env.new(nil, app_name, keys, options)
    namespace = My.Custom.Namespace
    with_namespace = Env.new(namespace, app_name, keys, options)

    """
    #{insert_custom_docs(docs)}

    A call to `#{module}.#{function_name}()`:

    1. When the OS environment variable is not `nil`, then it'll return its
       casted value.
    2. When the OS environment variable is `nil`, then it'll try to get the
       value from the configuration file.
    3. When the configuration file does not contain the variable, then it'll
       return the default value if it's defined.
    4. When the default value is not defined and it's not required, it'll
    return `nil`, otherwise it'll return an error.

    A call to `#{module}.#{function_name}(namespace)` will try
    to do the same as before, but with a namespace (`atom()`). This is
    useful for spliting different configurations values for the same variable
    e.g. different environments.

    The OS environment variables expected are:

    - When no namespace is specified, then it'll be
    `$#{System.gen_env_name(no_namespace)}`.
    - When a namespace is specified e.g. `#{Macro.to_string(namespace)}`, then
    it'll be `$#{System.gen_env_name(with_namespace)}`.

    The expected application configuration would be as follows:

    - Without namespace:

      ```
      #{gen_config_code(no_namespace)}
      ```

    - With namespace e.g. `#{Macro.to_string(namespace)}`:

      ```
      #{gen_config_code(with_namespace)}
      ```
    """
  end


  @doc """
  Generates short docs for a variable given its `module`, `function_name`,
  and custom `docs`.
  """
  @spec gen_short_docs(
          module(),
          function_name(),
          docs()
        ) :: binary()
  def gen_short_docs(module, function_name, docs)

  def gen_short_docs(module, function_name, docs) do
    module = Macro.to_string(module)

    """
    #{insert_custom_docs(docs)}

    Bang version of `#{module}.#{function_name}/0` (fails on error).
    """
  end

  @doc """
  Generates reload docs for a variable given its `module` and `function_name`.
  """
  @spec gen_reload_docs(
          module(),
          function_name()
        ) :: binary()
  def gen_reload_docs(module, function_name)

  def gen_reload_docs(module, function_name) do
    module = Macro.to_string(module)

    """
    Reloads the value for `#{module}.#{function_name}/0`. Optionally, receives
    the `namespace` for the variable.
    """
  end

  @doc """
  Generates put docs for a variable given its `module` and `function_name`.
  """
  @spec gen_put_docs(
          module(),
          function_name()
        ) :: binary()
  def gen_put_docs(module, function_name)

  def gen_put_docs(module, function_name) do
    module = Macro.to_string(module)

    """
    Puts the `value` to `#{module}.#{function_name}/0`. Optionally, receives
    the `namespace`.
    """
  end

  #########
  # Helpers

  @doc false
  @spec insert_custom_docs(docs()) :: binary()
  def insert_custom_docs(nil), do: "Use `@envdoc` to document this variable"
  def insert_custom_docs(docs), do: docs

  @doc false
  @spec gen_config_code(Env.t()) :: binary()
  def gen_config_code(env)

  def gen_config_code(%Env{namespace: nil, app_name: app_name} = env) do
    "config #{inspect(app_name)},\n#{expand(env)}"
  end

  def gen_config_code(%Env{namespace: namespace, app_name: app_name} = env) do
    "config #{inspect(app_name)}, #{inspect(namespace)},\n#{expand(env)}"
  end

  @doc false
  @spec expand(Env.t()) :: binary()
  def expand(env)

  def expand(%Env{keys: keys} = env) do
    expand(1, keys, env)
  end

  @doc false
  @spec expand(pos_integer(), Env.keys(), Env.options()) :: binary()
  def expand(indent, keys, env)

  def expand(indent, [key], %Env{options: options} = env) do
    type = System.get_type(env)
    default = options[:default]

    if is_nil(default) do
      "#{String.duplicate("  ", indent)}#{key}: #{inspect(type)}()"
    else
      "#{String.duplicate("  ", indent)}#{key}: #{inspect(type)}()" <>
        " # Defaults to #{inspect(default)}"
    end
  end

  def expand(indent, [key | keys], %Env{} = env) do
    "#{String.duplicate("  ", indent)}#{key}: [\n" <>
      "#{expand(indent + 1, keys, env)}\n" <>
      "#{String.duplicate("  ", indent)}]"
  end
end
