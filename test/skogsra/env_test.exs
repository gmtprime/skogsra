defmodule Skogsra.EnvTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env

  describe "new/2" do
    test "adds default options" do
      %Env{options: options} = Env.new(nil, :app, :key, [])

      assert options[:skip_system] == false
      assert options[:skip_config] == false
      assert options[:required] == false
      assert options[:cached] == true
    end

    test "converts single key to a list" do
      assert %Env{keys: [:key]} = Env.new(nil, :app, :key, [])
    end

    test "sets namespace" do
      assert %Env{namespace: Test} = Env.new(nil, :app, :key, namespace: Test)
    end
  end

  describe "skip_system?/1" do
    test "gets default value for skip system if not set" do
      env = Env.new(nil, :app, :key, [])

      assert not Env.skip_system?(env)
    end

    test "gets value for skip system if set" do
      env = Env.new(nil, :app, :key, skip_system: true)

      assert Env.skip_system?(env)
    end
  end

  describe "skip_config?/1" do
    test "gets default value for skip config if not set" do
      env = Env.new(nil, :app, :key, [])

      assert not Env.skip_config?(env)
    end

    test "gets value for skip config if set" do
      env = Env.new(nil, :app, :key, skip_config: true)

      assert Env.skip_config?(env)
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
      env = Env.new(nil, :app, [:a, :b], os_env: "FOO", skip_system: true)

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

    test "when atom" do
      assert :atom == Env.get_type(:atom)
    end

    test "when other" do
      assert :binary == Env.get_type([])
    end
  end
end
