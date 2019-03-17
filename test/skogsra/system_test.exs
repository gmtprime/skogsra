defmodule Skogsra.SystemTest do
  use ExUnit.Case

  alias Skogsra.Env
  alias Skogsra.System

  describe "get_env/1" do
    test "when skip_system is true, skips it" do
      env = Env.new(nil, :system_app, [:a, :b], skips_system: true)

      assert nil == System.get_env(env)
    end

    test "when defined, gets the value" do
      SystemMock.put_env("SYSTEM_APP_A_B", "42")

      env = Env.new(nil, :system_app, [:a, :b], default: 21)

      assert 42 == System.get_env(env)
    end

    test "when undefined, does not get the value" do
      env = Env.new(nil, :system_app, [:a, :c], [])

      assert nil == System.get_env(env)
    end
  end

  describe "gen_env_name/1" do
    test "when os_env defined, returns it" do
      env = Env.new(nil, :app, [:a, :b], os_env: "FOO")

      assert "FOO" == System.gen_env_name(env)
    end

    test "when namespace is nil, is not present" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert "APP_A_B" == System.gen_env_name(env)
    end

    test "when namespace is not nil, is present" do
      env = Env.new(My.Custom.Namespace, :app, [:a, :b], [])

      assert "MY_CUSTOM_NAMESPACE_APP_A_B" == System.gen_env_name(env)
    end
  end

  describe "gen_app_name/1" do
    test "transforms app_name to binary" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert "APP" == System.gen_app_name(env)
    end
  end

  describe "gen_keys/1" do
    test "transforms keys to binary" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert "A_B" == System.gen_keys(env)
    end
  end

  describe "gen_namespace/1" do
    test "when nil, then is empty" do
      env = Env.new(nil, :app, :key, [])

      assert "" == System.gen_namespace(env)
    end

    test "when not nil, then converts it to binary" do
      env = Env.new(My.Custom.Namespace, :app, :key, [])

      assert "MY_CUSTOM_NAMESPACE_" == System.gen_namespace(env)
    end
  end

  describe "cast/3" do
    test "casts value as default type" do
      env = Env.new(nil, :app, :key, default: 42)
      assert 42 == System.cast(env, "FOO", "42")
    end

    test "casts value as type" do
      env = Env.new(nil, :app, :key, type: :integer)
      assert 42 == System.cast(env, "FOO", "42")
    end
  end

  describe "get_type/1" do
    test "returns default type" do
      env = Env.new(nil, :app, :key, default: 42)
      assert :integer == System.get_type(env)
    end

    test "returns binary type when no default" do
      env = Env.new(nil, :app, :key, [])
      assert :binary == System.get_type(env)
    end

    test "returns type" do
      env = Env.new(nil, :app, :key, type: :float)
      assert :float == System.get_type(env)
    end

    test "type takes precedence over default" do
      env = Env.new(nil, :app, :key, type: :float, default: 42)
      assert :float == System.get_type(env)
    end
  end

  describe "type?/1" do
    test "when nil" do
      assert nil == System.type?(nil)
    end

    test "when binary" do
      assert :binary == System.type?("foo")
    end

    test "when integer" do
      assert :integer == System.type?(42)
    end

    test "when float" do
      assert :float == System.type?(42.0)
    end

    test "when atom" do
      assert :atom == System.type?(:atom)
    end

    test "when other" do
      assert nil == System.type?([])
    end
  end

  defmodule CustomType do
    def cast(value) do
      with {value, ""} <- Integer.parse(value, 16) do
        {:ok, value}
      else
        _ ->
          {:error, "error"}
      end
    end
  end

  describe "do_cast/3" do
    test "casts binary" do
      assert "foo" == System.do_cast(:binary, "FOO", "foo")
    end

    test "casts integer" do
      assert 42 == System.do_cast(:integer, "FOO", "42")
    end

    test "fails to cast a integer" do
      assert nil == System.do_cast(:integer, "FOO", "A")
    end

    test "casts float" do
      assert 42.42 == System.do_cast(:float, "FOO", "42.42")
    end

    test "fails to cast a float" do
      assert nil == System.do_cast(:float, "FOO", "1,0")
    end

    test "casts boolean" do
      assert true == System.do_cast(:boolean, "FOO", "TRUE")
      assert false == System.do_cast(:boolean, "FOO", "FALSE")
    end

    test "fails to cast a boolean" do
      assert nil == System.do_cast(:boolean, "FOO", "1")
    end

    test "casts atom" do
      assert :foo == System.do_cast(:atom, "FOO", "foo")
    end

    test "casts custom type" do
      assert 10 == System.do_cast({CustomType, :cast}, "FOO", "A")
    end

    test "fails to cast a custom type" do
      assert nil == System.do_cast({CustomType, :cast}, "FOO", "R")
    end
  end
end
