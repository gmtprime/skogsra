defmodule Skogsra.Docs do
  @moduledoc """
  This module defines the documentation generators.
  """
  alias Skogsra.Env

  @typedoc """
  Custom docs.
  """
  @type docs :: nil | false | binary()

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

  def gen_full_docs(_, _, _, _, _, false), do: false
  def gen_full_docs(module, function_name, app_name, keys, options, docs) do
    if Application.get_env(:skogsra, :generate_docs, true) do
      do_gen_full_docs(module, function_name, app_name, keys, options, docs)
    else
      "#{insert_custom_docs(docs)}"
    end
  end

  defp do_gen_full_docs(module, function_name, app_name, keys, options, docs) do
    module = Macro.to_string(module)
    no_namespace = Env.new(nil, app_name, keys, options)
    namespace = My.Custom.Namespace
    with_namespace = Env.new(namespace, app_name, keys, options)

    """
    #{insert_custom_docs(docs)}

    Calling `#{module}.#{function_name}()` will try to retrive a casted value
    in the following order:

    1. From the OS environment variable `#{Env.os_env(no_namespace)}` (unless
       `skip_system: true` ).
    2. From the application config (unless `skip_config: true`) e.g:
       ```
       #{gen_config_code(no_namespace)}
       ```
    3. From the default value if defined. If the variables has the option
       `required: true` and no default is defined, then the function will
       return an error.

    Calling `#{module}.#{function_name}(#{inspect(namespace)})` will try to
    retrieve a casted value in the following order:

    1. From the OS environment variable `#{Env.os_env(with_namespace)}` (unless
       `skip_system: true`).
    2. From the application config (unless `skip_config: true`) e.g:
       ```
       #{gen_config_code(with_namespace)}
       ```
    3. From the OS environment variable `#{Env.os_env(no_namespace)}` (unless
       `skip_system: true` ).
    4. From the application config (unless `skip_config: true`) e.g:
       ```
       #{gen_config_code(no_namespace)}
       ```
    5. From the default value if defined. If the variables has the option
       `required: true` and no default is defined, then the function will
       return an error.
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

  def gen_short_docs(_, _, false), do: false
  def gen_short_docs(module, function_name, docs) do
    module = Macro.to_string(module)

    """
    #{insert_custom_docs(docs)}

    Bang version of `#{module}.#{function_name}/0` (fails on error). Optionally,
    receives the `namespace` for the variable.
    """
  end

  @doc """
  Generates reload docs for a variable given its `module` and `function_name`.
  """
  @spec gen_reload_docs(
          module(),
          function_name(),
          docs()
        ) :: binary()
  def gen_reload_docs(module, function_name, docs)

  def gen_reload_docs(_, _, false), do: false
  def gen_reload_docs(module, function_name, _) do
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
          function_name(),
          docs()
        ) :: binary()
  def gen_put_docs(module, function_name, docs)

  def gen_put_docs(_, _, false), do: false
  def gen_put_docs(module, function_name, _) do
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
  @spec expand(pos_integer(), Env.keys(), Env.t()) :: binary()
  def expand(indent, keys, env)

  def expand(indent, [key], %Env{} = env) do
    type = Env.type(env)
    default = Env.default(env)

    if is_nil(default) do
      "#{String.duplicate("\t", indent)}#{key}: #{type}()"
    else
      "#{String.duplicate("\t", indent)}#{key}: #{type}()" <>
        " # Defaults to #{inspect(default)}"
    end
  end

  def expand(indent, [key | keys], %Env{} = env) do
    "#{String.duplicate("  ", indent)}#{key}: [\n" <>
      "#{expand(indent + 1, keys, env)}\n" <>
      "#{String.duplicate("  ", indent)}]"
  end
end
