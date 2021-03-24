defmodule Skogsra.EnvTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env

  describe "new/1" do
    test "requires app_name" do
      params = %{
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      assert_raise ArgumentError, "missing app name", fn ->
        Env.new(params)
      end
    end

    test "requires module" do
      params = %{
        app_name: :app,
        function: :function,
        keys: :key,
        options: []
      }

      assert_raise ArgumentError, "missing module", fn ->
        Env.new(params)
      end
    end

    test "requires function" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        keys: :key,
        options: []
      }

      assert_raise ArgumentError, "missing function name", fn ->
        Env.new(params)
      end
    end

    test "adds default options" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      assert %Env{options: options} = Env.new(params)
      assert options[:required] == false
      assert options[:cached] == true
      assert options[:binding_order] == [:system, :config]
      assert options[:binding_skip] == []
    end

    test "converts single key to a list" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      assert %Env{keys: [:key]} = Env.new(params)
    end

    test "sets namespace" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [namespace: Test]
      }

      assert %Env{namespace: Test} = Env.new(params)
    end
  end

  describe "os_env/1" do
    test "when os_env defined, returns it" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: [:a, :b],
        options: [os_env: "FOO"]
      }

      env = Env.new(params)

      assert "FOO" == Env.os_env(env)
    end

    test "when namespace is nil, is not present" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: [:a, :b],
        options: []
      }

      env = Env.new(params)

      assert "APP_A_B" == Env.os_env(env)
    end

    test "when namespace is not nil, is present" do
      params = %{
        namespace: My.Custom.Namespace,
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: [:a, :b],
        options: []
      }

      env = Env.new(params)

      assert "MY_CUSTOM_NAMESPACE_APP_A_B" == Env.os_env(env)
    end

    test "when skips system, returns empty string" do
      params = %{
        namespace: My.Custom.Namespace,
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: [:a, :b],
        options: [os_env: "FOO", binding_skip: [:system]]
      }

      env = Env.new(params)

      assert "" == Env.os_env(env)
    end
  end

  describe "type/1" do
    test "gets default value type if none is defined" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [default: 42]
      }

      env = Env.new(params)

      assert :integer = Env.type(env)
    end

    test "gets type when defined" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [type: :integer]
      }

      env = Env.new(params)

      assert :integer = Env.type(env)
    end
  end

  describe "default/1" do
    test "gets default value if set" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [default: 42]
      }

      env = Env.new(params)

      assert 42 = Env.default(env)
    end
  end

  describe "required?/1" do
    test "gets default value for required if not set" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      env = Env.new(params)

      refute Env.required?(env)
    end

    test "gets value for required if set" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [required: true]
      }

      env = Env.new(params)

      assert Env.required?(env)
    end
  end

  describe "cached?/1" do
    test "gets default value for cached if not set" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      env = Env.new(params)

      assert Env.cached?(env)
    end

    test "gets value for cached if set" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [cached: false]
      }

      env = Env.new(params)

      refute Env.cached?(env)
    end
  end

  describe "binding_order/1" do
    test "returns not skippable variable bindings" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: [
          binding_order: [:system, :config],
          binding_skip: [:system]
        ]
      }

      env = Env.new(params)

      assert [:config] = Env.binding_order(env)
    end
  end

  describe "gen_namespace/1" do
    test "when nil, then is empty" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      env = Env.new(params)

      assert "" == Env.gen_namespace(env)
    end

    test "when not nil, then converts it to binary" do
      params = %{
        namespace: My.Custom.Namespace,
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      env = Env.new(params)

      assert "MY_CUSTOM_NAMESPACE_" == Env.gen_namespace(env)
    end
  end

  describe "gen_app_name/1" do
    test "transforms app_name to binary" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: :key,
        options: []
      }

      env = Env.new(params)

      assert "APP" == Env.gen_app_name(env)
    end
  end

  describe "gen_keys/1" do
    test "transforms keys to binary" do
      params = %{
        app_name: :app,
        module: __MODULE__,
        function: :function,
        keys: [:a, :b],
        options: []
      }

      env = Env.new(params)

      assert "A_B" == Env.gen_keys(env)
    end
  end

  describe "get_type/1" do
    test "when nil" do
      assert :binary == Env.get_type(nil)
    end

    test "when binary" do
      assert :binary == Env.get_type("foo")
    end

    test "when integer" do
      assert :integer == Env.get_type(42)
    end

    test "when float" do
      assert :float == Env.get_type(42.0)
    end

    test "when atom" do
      assert :atom == Env.get_type(:atom)
    end

    test "when other" do
      assert :any == Env.get_type([])
    end
  end
end
