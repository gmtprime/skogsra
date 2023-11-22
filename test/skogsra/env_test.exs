defmodule Skogsra.EnvTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env

  describe "new/2" do
    test "adds default options" do
      %Env{options: options} = Env.new(nil, :app, :key, [])

      assert options[:required] == false
      assert options[:cached] == true
      assert options[:binding_order] == [:system, :config]
      assert options[:binding_skip] == []
    end

    test "converts single key to a list" do
      assert %Env{keys: [:key]} = Env.new(nil, :app, :key, [])
    end

    test "sets namespace" do
      assert %Env{namespace: Test} = Env.new(nil, :app, :key, namespace: Test)
    end
  end

  describe "os_env/1" do
    test "when os_env defined, returns it" do
      env = Env.new(nil, :app, [:a, :b], os_env: "FOO")

      assert "FOO" == Env.os_env(env)
    end

    test "when namespace is nil, is not present" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert "APP_A_B" == Env.os_env(env)
    end

    test "when namespace is not nil, is present" do
      env = Env.new(My.Custom.Namespace, :app, [:a, :b], [])

      assert "MY_CUSTOM_NAMESPACE_APP_A_B" == Env.os_env(env)
    end

    test "when skips system, returns empty string" do
      env = Env.new(nil, :app, [:a, :b], os_env: "FOO", binding_skip: [:system])

      assert "" == Env.os_env(env)
    end
  end

  describe "type/1" do
    test "gets default value type if none is defined" do
      env = Env.new(nil, :app, :key, default: 42)

      assert :integer = Env.type(env)
    end

    test "gets type when defined" do
      env = Env.new(nil, :app, :key, type: :integer)

      assert :integer = Env.type(env)
    end
  end

  describe "default/1" do
    test "gets default value if set" do
      env = Env.new(nil, :app, :key, default: 42)

      assert 42 = Env.default(env)
    end

    test "should get the default value for the current environment" do
      env =
        Env.new(nil, :app, :key,
          default: 0,
          env_overrides: [test: [default: 42]]
        )

      assert 42 = Env.default(env)
    end
  end

  describe "required?/1" do
    test "gets default value for required if not set" do
      env = Env.new(nil, :app, :key, [])

      assert not Env.required?(env)
    end

    test "gets value for required if set" do
      env = Env.new(nil, :app, :key, required: true)

      assert Env.required?(env)
    end

    test "should get the required value for the current environment" do
      env =
        Env.new(nil, :app, :key,
          required: false,
          env_overrides: [test: [required: true]]
        )

      assert Env.required?(env)
    end
  end

  describe "cached?/1" do
    test "gets default value for cached if not set" do
      env = Env.new(nil, :app, :key, [])

      assert Env.cached?(env)
    end

    test "gets value for cached if set" do
      env = Env.new(nil, :app, :key, cached: false)

      assert not Env.cached?(env)
    end
  end

  describe "binding_order/1" do
    test "returns not skippable variable bindings" do
      options = [
        binding_order: [:system, :config],
        binding_skip: [:system]
      ]

      env = Env.new(nil, :app, :key, options)

      assert [:config] = Env.binding_order(env)
    end
  end

  describe "gen_namespace/1" do
    test "when nil, then is empty" do
      env = Env.new(nil, :app, :key, [])

      assert "" == Env.gen_namespace(env)
    end

    test "when not nil, then converts it to binary" do
      env = Env.new(My.Custom.Namespace, :app, :key, [])

      assert "MY_CUSTOM_NAMESPACE_" == Env.gen_namespace(env)
    end
  end

  describe "gen_app_name/1" do
    test "transforms app_name to binary" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert "APP" == Env.gen_app_name(env)
    end
  end

  describe "gen_keys/1" do
    test "transforms keys to binary" do
      env = Env.new(nil, :app, [:a, :b], [])

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

    test "when boolean" do
      assert :boolean == Env.get_type(true)
      assert :boolean == Env.get_type(false)
    end

    test "when atom" do
      assert :atom == Env.get_type(:atom)
    end

    test "when other" do
      assert :any == Env.get_type([])
    end
  end

  describe "find_environment/0" do
    test "should get the current environment" do
      assert :test = Env.find_environment()
    end
  end
end
