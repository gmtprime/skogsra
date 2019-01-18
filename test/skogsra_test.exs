defmodule SkogsraTest do
  use ExUnit.Case, async: true

  #######
  # Tests

  #################
  # Tests for macro

  describe "app_env/4" do
    defmodule TestVars do
      use Skogsra

      app_env(:my_number, :my_app, [:key, :number], default: 42)

      app_env(:my_list, :my_app, :list, type: {__MODULE__, :get_list})

      def get_list(value) when is_binary(value) do
        list =
          value
          |> String.split(",")
          |> Stream.map(&String.trim/1)
          |> Enum.map(fn e -> e |> Integer.parse() |> elem(0) end)

        {:ok, list}
      end
    end

    test "creates functions" do
      assert is_function(&TestVars.my_number/0)
      assert is_function(&TestVars.my_number/1)
      assert is_function(&TestVars.my_number/2)

      assert is_function(&TestVars.my_number!/0)
      assert is_function(&TestVars.my_number!/1)

      assert is_function(&TestVars.my_list/0)
      assert is_function(&TestVars.my_list/1)
      assert is_function(&TestVars.my_list/2)

      assert is_function(&TestVars.my_list!/0)
      assert is_function(&TestVars.my_list!/1)
    end

    test "retrieves variable from system" do
      SystemMock.put_env("MY_APP_KEY_NUMBER", "21")
      assert {:ok, 21} = TestVars.my_number()
    end

    test "retrieves variable from specific namespace in system" do
      SystemMock.put_env("NAMESPACE_MY_APP_KEY_NUMBER", "21")
      assert {:ok, 21} = TestVars.my_number(Namespace)
    end

    test "retrieves variable from config" do
      ApplicationMock.put_env(:my_app, :key, number: 21)
      assert {:ok, 21} = TestVars.my_number()
    end

    test "retrieves variable from specific namespace in config" do
      ApplicationMock.put_env(:my_app, Namespace, key: [number: 21])
      assert {:ok, 21} = TestVars.my_number(Namespace)
    end

    test "casts variable with custom function" do
      SystemMock.put_env("MY_APP_LIST", "1, 2, 3")
      assert {:ok, [1, 2, 3]} = TestVars.my_list()
    end
  end

  ########################################
  # Tests for environment variable getters

  describe "get_env/1" do
    test "by default caches the variable" do
      env = [app_name: :my_app, parameters: [:key], options: [type: :integer]]
      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.get_env(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 21} = Skogsra.get_env(env)
    end

    test "when is not cached changes every time" do
      env = [
        app_name: :my_app,
        parameters: [:key],
        options: [type: :integer, cached: false]
      ]

      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.get_env(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 42} = Skogsra.get_env(env)
    end
  end

  describe "reload/1" do
    test "reloads value every time" do
      env = [
        app_name: :my_app,
        parameters: [:key],
        options: [type: :integer]
      ]

      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.reload(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 42} = Skogsra.reload(env)
    end
  end

  ###############################
  # Test for finite state machine

  describe "fsm_entry/1" do
    test "by default caches the variable" do
      env = [app_name: :my_app, parameters: [:key], options: [type: :integer]]
      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.fsm_entry(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 21} = Skogsra.fsm_entry(env)
    end

    test "when is not cached changes every time" do
      env = [
        app_name: :my_app,
        parameters: [:key],
        options: [type: :integer, cached: false]
      ]

      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.fsm_entry(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 42} = Skogsra.fsm_entry(env)
    end
  end

  describe "get_cached/1" do
    test "when is not cached, caches and returns it" do
      env = [app_name: :my_app, parameters: [:key], options: [type: :integer]]
      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.get_cached(env)
    end

    test "when is cached, returns the cached value" do
      env = [app_name: :my_app, parameters: [:key], options: [type: :integer]]
      env = gen_env(env, create_cache: true, create_system: true, value: "21")

      assert {:ok, 21} = Skogsra.get_cached(env)

      SystemMock.put_env("MY_APP_KEY", "42")

      assert {:ok, 21} = Skogsra.get_cached(env)
    end
  end

  describe "get_system/1" do
    test "when is not skipped and the value is not nil, returns value" do
      env = [app_name: :my_app, parameters: [:key]]
      env = gen_env(env, create_cache: true, create_system: true, value: 21)

      assert {:ok, 21} = Skogsra.get_system(env)
    end

    test "when not skipped, value is nil, config not nil, returns config" do
      env = [app_name: :my_app, parameters: [:key]]
      env = gen_env(env, create_cache: true, create_config: true, value: 21)

      assert {:ok, 21} = Skogsra.get_system(env)
    end

    test "when not skipped, value is nil, config nil, returns default" do
      env = [app_name: :my_app, parameters: [:key], options: [default: 42]]
      env = gen_env(env, [])

      assert {:ok, 42} = Skogsra.get_system(env)
    end

    test "when is skipped, config not nil, returns config" do
      env = [app_name: :my_app, parameters: [:key]]
      env = gen_env(env, create_cache: true, create_config: true, value: 21)

      assert {:ok, 21} = Skogsra.get_system(env)
    end

    test "when is skipped, config nil, returns default" do
      env = [app_name: :my_app, parameters: [:key], options: [default: 42]]
      env = gen_env(env, [])

      assert {:ok, 42} = Skogsra.get_system(env)
    end
  end

  describe "get_config/1" do
    test "when is not skipped and the value is not nil, returns value" do
      env = [app_name: :my_app, parameters: [:key]]
      env = gen_env(env, create_cache: true, create_config: true, value: 21)

      assert {:ok, 21} = Skogsra.get_config(env)
    end

    test "when is not skipped and the value is nil, returns default" do
      env = [options: [default: 42]]
      env = gen_env(env, [])

      assert {:ok, 42} = Skogsra.get_config(env)
    end

    test "when is skipped, then returns default value" do
      env = [options: [skip_config: true, default: 42]]
      env = gen_env(env, [])

      assert {:ok, 42} = Skogsra.get_config(env)
    end
  end

  describe "get_default/1" do
    test "when default value is not nil, returns it" do
      env = [options: [default: 42]]
      env = gen_env(env, [])

      assert {:ok, 42} = Skogsra.get_default(env)
    end

    test "when is required and default value is nil, errors" do
      env = [options: [required: true]]
      env = gen_env(env, [])

      assert {:error, _} = Skogsra.get_default(env)
    end

    test "when is not required and default value is nil, returns nil" do
      env = gen_env([], [])

      assert {:ok, nil} = Skogsra.get_default(env)
    end
  end

  ########################
  # Test for cache helpers

  describe "cache" do
    test "retrieves a stored value" do
      env = [app_name: :my_app, parameters: [:a]]
      opts = [create_cache: true]
      env = gen_env(env, opts)

      assert :ok = Skogsra.store(env, 42)
      assert {:ok, 42} = Skogsra.retrieve(env)
    end

    test "cannot retrieve an unexistent value" do
      env = [app_name: :my_app, parameters: [:a]]
      opts = [create_cache: true]
      env = gen_env(env, opts)

      assert {:error, _} = Skogsra.retrieve(env)
    end

    test "cannot retrieve a deleted value" do
      env = [app_name: :my_app, parameters: [:a]]
      opts = [create_cache: true]
      env = gen_env(env, opts)

      assert :ok = Skogsra.store(env, 42)
      assert {:ok, 42} = Skogsra.retrieve(env)
      assert :ok = Skogsra.delete(env)
      assert {:error, _} = Skogsra.retrieve(env)
    end
  end

  ###########################################
  # Test for OS environment variable helpers.

  describe "get_system_env/1" do
    test "gets system variable" do
      env = [
        app_name: :my_app,
        parameters: [:parameter],
        options: [default: 21]
      ]

      env = gen_env(env, create_system: true, value: "42")
      assert 42 == Skogsra.get_system_env(env)
    end
  end

  describe "gen_env_var/1" do
    test "when there is an alias and namespace is nil" do
      env = gen_env([options: [os_env: "MY_ALIAS"]], [])
      assert "MY_ALIAS" == Skogsra.gen_env_var(env)
    end

    test "when there is an alias and namespace is not nil" do
      env = [namespace: Namespace, options: [os_env: "MY_ALIAS"]]
      env = gen_env(env, [])
      assert "MY_ALIAS" == Skogsra.gen_env_var(env)
    end

    test "when namespace is nil, it's not in the name of the variable" do
      env = gen_env(app_name: :my_app, parameters: [:a, :b])
      assert "MY_APP_A_B" == Skogsra.gen_env_var(env)
    end

    test "when namespace is not nil, it's in the name of the variable" do
      env = [namespace: Namespace, app_name: :my_app, parameters: [:a, :b]]
      env = gen_env(env)
      assert "NAMESPACE_MY_APP_A_B" == Skogsra.gen_env_var(env)
    end
  end

  describe "gen_namespace/1" do
    test "when is an atom, generates an uppercase string" do
      namespace = My.Namespace
      assert "MY_NAMESPACE" == Skogsra.gen_namespace(namespace)
    end
  end

  describe "gen_app_name/1" do
    test "when is an atom, generates an uppercase string" do
      app_name = :my_app
      assert "MY_APP" == Skogsra.gen_app_name(app_name)
    end
  end

  describe "gen_parameters/1" do
    test "when is a list of atoms, generates a snakecase uppercase string" do
      parameters = [:a, :b, :c]
      assert "A_B_C" == Skogsra.gen_parameters(parameters)
    end
  end

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
      env = [app_name: :skogsra_test, parameters: [:key]]
      value = "some_value"

      env = gen_env(env, create_config: true, value: value)

      assert value == Skogsra.get_config_env(env)
    end

    test "when namespace is not nil" do
      env = [namespace: Namespace, app_name: :skogsra_test, parameters: [:key]]
      value = "some_value"

      env = gen_env(env, create_config: true, value: value)

      assert value == Skogsra.get_config_env(env)
    end
  end

  describe "search_keys/2" do
    test "gets single value when parameters is an empty list" do
      value = "some_value"
      parameters = []

      assert value == Skogsra.search_keys(value, parameters)
    end

    test "gets value from a list of parameters" do
      value = "some_value"
      values = [a: [b: [c: value]]]
      parameters = [:a, :b, :c]

      assert value == Skogsra.search_keys(values, parameters)
    end
  end

  ##############
  # Test helpers

  ##
  # Generates a variable.
  #
  # - `env` - Receives a list with the same parameters as Skogsra variable
  # struct:
  #   - `namespace` - An atom with the namespace.
  #   - `app_name` - An atom with the app name.
  #   - `parameters` - A list of atoms.
  #   - `options` - Valid options for a variable.
  # - `options` -
  #   - `value` - Value of the variable.
  #   - `create_system` - Whether it creates the OS environment variable or
  #   not.
  #   - `create_config` - Whether it creates the application variable or not.
  #   - `create_cache` - Whether it creates a private cache for the test or
  #   not.
  def gen_env(env, options \\ []) do
    namespace = env[:namespace]
    app_name = env[:app_name]
    parameters = env[:parameters]
    opts = Keyword.get(env, :options, [])

    value = options[:value]
    create_cache? = Keyword.get(options, :create_cache, false)
    create_system? = Keyword.get(options, :create_system, false)
    create_config? = Keyword.get(options, :create_config, false)

    env =
      if create_cache? do
        :skogsra_test_cache
        |> :ets.new([:set, :public])
        |> Skogsra.new_env(namespace, app_name, parameters, opts)
      else
        Skogsra.new_env(namespace, app_name, parameters, opts)
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
           parameters: [parameter]
         },
         value
       ) do
    ApplicationMock.put_env(app_name, parameter, value)
  end

  defp create_config(
         %Skogsra{
           namespace: nil,
           app_name: app_name,
           parameters: [parameter | parameters]
         },
         value
       ) do
    value = create_value(parameters, value)
    ApplicationMock.put_env(app_name, parameter, value)
  end

  defp create_config(
         %Skogsra{
           namespace: namespace,
           app_name: app_name,
           parameters: parameters
         },
         value
       ) do
    value = create_value(parameters, value)
    ApplicationMock.put_env(app_name, namespace, value)
  end

  ##
  # Creates a recursive value.
  defp create_value([parameter], value) do
    [{parameter, value}]
  end

  defp create_value([parameter | parameters], value) do
    [{parameter, create_value(parameters, value)}]
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
