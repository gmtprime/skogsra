defmodule Skogsra.SysTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env
  alias Skogsra.Sys

  describe "get_env/1" do
    test "when skip_system is true, skips it" do
      env = Env.new(nil, :system_app, [:a, :b], skips_system: true)

      assert nil == Sys.get_env(env)
    end

    test "when defined, gets the value" do
      SystemMock.put_env("SYSTEM_APP_A_B", "42")

      env = Env.new(nil, :system_app, [:a, :b], default: 21)

      assert 42 == Sys.get_env(env)
    end

    test "when undefined, does not get the value" do
      env = Env.new(nil, :system_app, [:a, :c], [])

      assert nil == Sys.get_env(env)
    end

    test "when cast is not possible, does not get the value" do
      SystemMock.put_env("SYSTEM_APP_KEY", "42.0")

      env = Env.new(nil, :system_app, :key, type: :integer)

      assert nil == Sys.get_env(env)
    end
  end
end
