defmodule SkogsraTest do
  use ExUnit.Case, async: true
  use PropCheck

  #######
  # Tests

  ###########################################
  # Test for OS environment variable helpers.

  describe "cast/3" do
    test "when default and type are nil, casts to binary" do
      env = gen_env([], [])
      assert "42" == Skogsra.cast(env, "ENV", "42")
    end

    test "when default is nil but type is defined, casts to type" do
      env = gen_env([options: [type: :integer]], [])
      assert 42 == Skogsra.cast(env, "ENV", "42")
    end

    test "when type is nil but default is defined, casts to default type" do
      env = gen_env([options: [default: 21]], [])
      assert 42 == Skogsra.cast(env, "ENV", "42")
    end

    test "when type and default are defined, casts to type" do
      env = gen_env([options: [type: :integer, default: "21"]], [])
      assert 42 == Skogsra.cast(env, "ENV", "42")
    end
  end

  describe "type?/1" do
    test "when is binary" do
      assert Skogsra.type?("binary") == :binary
    end

    test "when is integer" do
      assert Skogsra.type?(42) == :integer
    end

    test "when is float" do
      assert Skogsra.type?(42.0) == :float
    end

    test "when is boolean" do
      assert Skogsra.type?(true) == :boolean
    end

    test "when is atom" do
      assert Skogsra.type?(:atom) == :atom
    end

    test "when is nil" do
      assert Skogsra.type?(nil) == nil
    end

    test "when is other type" do
      assert Skogsra.type?([]) == nil
    end
  end

  describe "do_cast/3" do
    test "when value is integer casts to integer" do
      assert 42 == Skogsra.do_cast("ENV", "42", :integer)
    end

    test "when value is float casts to float" do
      assert 42.0 == Skogsra.do_cast("ENV", "42.0", :float)
    end

    test "when value is boolean casts to boolean" do
      assert true == Skogsra.do_cast("ENV", "True", :boolean)
      assert false == Skogsra.do_cast("ENV", "False", :boolean)
    end

    test "when value is binary casts to atom" do
      assert :some_atom == Skogsra.do_cast("ENV", "some_atom", :atom)
    end

    test "when value is binary casts to binary" do
      assert "some_binary" == Skogsra.do_cast("ENV", "some_binary", :binary)
    end

    test "when value is of other format and a function is provided" do
      defmodule DoCast do
        def f(value) do
          {:ok, String.split(value, ", ")}
        end
      end

      assert ["1", "2", "3"] == Skogsra.do_cast("ENV", "1, 2, 3", {DoCast, :f})
    end
  end

  ###################################################
  # Test for application environment variable helpers

  describe "get_config_env/1" do
    test "when namespace is nil" do
      env = [app_name: :skogsra_test, properties: [:key]]
      value = "some_value"

      env = gen_env(env, [create_config: true, value: value])

      assert value == Skogsra.get_config_env(env)
    end

    test "when namespace is not nil" do
      env = [namespace: Namespace, app_name: :skogsra_test, properties: [:key]]
      value = "some_value"

      env = gen_env(env, [create_config: true, value: value])

      assert value == Skogsra.get_config_env(env)
    end
  end

  describe "search_keys/2" do

    test "gets single value when properties is an empty list" do
      value = "some_value"
      properties = []

      assert value == Skogsra.search_keys(value, properties)
    end

    test "gets value from a list of properties" do
      value = "some_value"
      values = [a: [b: [c: value]]]
      properties = [:a, :b, :c]

      assert value == Skogsra.search_keys(values, properties)
    end
  end

  ##############
  # Test helpers

  ##
  # Generates a variable.
  def gen_env(env, options \\ []) do
    value = options[:value]
    create_cache? = Keyword.get(options, :create_cache, false)
    create_system? = Keyword.get(options, :create_system, false)
    create_config? = Keyword.get(options, :create_config, false)

    namespace = env[:namespace]
    app_name = env[:app_name]
    properties = env[:properties]
    opts = Keyword.get(env, :options, [])

    env =
      if create_cache? do
        :skogsra_test_cache
        |> :ets.new([:set, :public])
        |> Skogsra.new_env(namespace, app_name, properties, opts)
      else
        Skogsra.new_env(namespace, app_name, properties, opts)
      end

    if create_system? do
      name = Skogsra.gen_env_var(env)
      SystemMock.put_env(name, value)
    end

    if create_config?, do: create_config(env, value)

    env
  end

  ##
  # Creates a valid config.
  defp create_config(
    %Skogsra{
      namespace: nil,
      app_name: app_name,
      properties: [property]
    },
    value
  ) do
    ApplicationMock.put_env(app_name, property, value)
  end

  defp create_config(
    %Skogsra{
      namespace: nil,
      app_name: app_name,
      properties: [property | properties]
    },
    value
  ) do
    value = create_value(properties, value)
    ApplicationMock.put_env(app_name, property, value)
  end

  defp create_config(
    %Skogsra{
      namespace: namespace,
      app_name: app_name,
      properties: properties
    },
    value
  ) do
    value = create_value(properties, value)
    ApplicationMock.put_env(app_name, namespace, value)
  end

  ##
  # Creates a recursive value.
  defp create_value([property], value) do
    [{property, value}]
  end

  defp create_value([property | properties], value) do
    [{property, create_value(properties, value)}]
  end
end
"""

  defmodule TestEnv do
    use Skogsra

    system_env :skogsra_static_var,
      static: true,
      default: "default"

    system_env :skogsra_dynamic_var,
      default: "default"

    system_env :skogsra_explicit_type,
      type: :integer,
      default: "42"

    system_env :skogsra_implicit_type,
      default: 42

    app_env :skogsra_app_static_var, :skogsra, :app_static_var,
      static: true,
      default: "default"

    app_env :skogsra_app_dynamic_var, :skogsra, :app_dynamic_var,
      default: "default"

    app_env :skogsra_app_explicit_type, :skogsra, :app_explicit_type,
      type: :integer,
      default: "42"

    app_env :skogsra_app_implicit_type, :skogsra, :app_implicit_type,
      default: 42
  end

  test "system_env static" do
    System.put_env("SKOGSRA_STATIC_VAR", "custom")

    assert TestEnv.skogsra_static_var == "default"

    System.delete_env("SKOGSRA_STATIC_VAR")
  end

  test "system_env dynamic" do
    System.put_env("SKOGSRA_DYNAMIC_VAR", "custom")

    assert TestEnv.skogsra_dynamic_var == "custom"

    System.delete_env("SKOGSRA_DYNAMIC_VAR")
  end

  test "system_env explicit type" do
    assert TestEnv.skogsra_explicit_type == 42
    System.put_env("SKOGSRA_EXPLICIT_TYPE", "41")
    assert TestEnv.skogsra_explicit_type == 41
    System.delete_env("SKOGSRA_EXPLICIT_TYPE")
  end

  test "system_env implicit type" do
    assert TestEnv.skogsra_implicit_type == 42
    System.put_env("SKOGSRA_IMPLICIT_TYPE", "41")
    assert TestEnv.skogsra_implicit_type == 41
    System.delete_env("SKOGSRA_IMPLICIT_TYPE")
  end

  test "app_env static var" do
    System.put_env("SKOGSRA_APP_STATIC_VAR", "custom")
    Application.put_env(:skogsra, :app_static_var, "custom")

    assert TestEnv.skogsra_app_static_var == "default"

    Application.delete_env(:skogsra, :app_static_var)
    System.delete_env("SKOGSRA_APP_STATIC_VAR")
  end

  test "app_env dynamic var" do
    assert TestEnv.skogsra_app_dynamic_var == "default"

    Application.put_env(:skogsra, :app_dynamic_var, "custom_app")
    assert TestEnv.skogsra_app_dynamic_var == "custom_app"
    Application.delete_env(:skogsra, :app_dynamic_var)

    System.put_env("SKOGSRA_APP_DYNAMIC_VAR", "custom_env")
    assert TestEnv.skogsra_app_dynamic_var == "custom_env"
    System.delete_env("SKOGSRA_APP_DYNAMIC_VAR")
  end

  test "app_env explicit type" do
    assert TestEnv.skogsra_app_explicit_type == 42

    Application.put_env(:skogsra, :app_explicit_type, 41)
    assert TestEnv.skogsra_app_explicit_type == 41
    Application.delete_env(:skogsra, :app_explicit_type)

    System.put_env("SKOGSRA_APP_EXPLICIT_TYPE", "40")
    assert TestEnv.skogsra_app_explicit_type == 40
    System.delete_env("SKOGSRA_APP_EXPLICIT_TYPE")
  end

  test "app_env implicit type" do
    assert TestEnv.skogsra_app_implicit_type == 42

    Application.put_env(:skogsra, :app_implicit_type, "41")
    assert TestEnv.skogsra_app_implicit_type == 41
    Application.delete_env(:skogsra, :app_implicit_type)

    System.put_env("SKOGSRA_APP_IMPLICIT_TYPE", "40")
    assert TestEnv.skogsra_app_implicit_type == 40
    System.delete_env("SKOGSRA_APP_IMPLICIT_TYPE")
  end

  test "get_env" do
    assert Skogsra.get_env("SKOGSRA_GET_ENV", 42) == 42

    System.put_env("SKOGSRA_GET_ENV", "41")
    assert Skogsra.get_env("SKOGSRA_GET_ENV", 42) == 41
    System.delete_env("SKOGSRA_GET_ENV")
  end

  test "get_env_as" do
    assert Skogsra.get_env_as(:integer, "SKOGSRA_GET_ENV_AS", "42") == 42

    System.put_env("SKOGSRA_GET_ENV_AS", "41")
    assert Skogsra.get_env_as(:integer, "SKOGSRA_GET_ENV_AS", "42") == 41
    System.delete_env("SKOGSRA_GET_ENV_AS")
  end

  test "get_app_env" do
    opts = [default: "42", domain: Skogsra.Domain, type: :integer, name: "SKOGSRA_GET_APP_ENV"]
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 42

    Application.put_env(:skogsra, Skogsra.Domain, [key: "41"])
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 41
    Application.delete_env(:skogsra, Skogsra)

    opts = [default: "42", type: :integer, name: "SKOGSRA_GET_APP_ENV"]

    Application.put_env(:skogsra, :key, "40")
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 40
    Application.delete_env(:skogsra, :key)

    System.put_env("SKOGSRA_GET_APP_ENV", "39")
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 39
    System.delete_env("SKOGSRA_GET_ENV_AS")
  end

  test "get_app_env nested domains" do
    opts = [default: "42", domain: [Skogsra.Nested, :domain], type: :integer,
            name: "SKOGSRA_GET_APP_ENV_NESTED_DOMAINS"]
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 42

    Application.put_env(:skogsra, Skogsra.Nested, [domain: [key: "41"]])
    assert Skogsra.get_app_env(:skogsra, :key, opts) == 41
    Application.delete_env(:skogsra, Skogsra)
  end

  test "type?" do
    assert Skogsra.type?("binary") == :any
    assert Skogsra.type?(42) == :integer
    assert Skogsra.type?(42.0) == :float
    assert Skogsra.type?(true) == :boolean
    assert Skogsra.type?(:atom) == :atom
  end
end
"""
