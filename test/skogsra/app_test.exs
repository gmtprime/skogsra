defmodule Skogsra.AppTest do
  use ExUnit.Case

  alias Skogsra.App
  alias Skogsra.Env

  describe "get_env/1" do
    test "when skip_config is true, returns nil" do
      env = Env.new(nil, :app, :key, skip_config: true)

      assert nil == App.get_env(env)
    end

    test "when it's defined, gets value" do
      ApplicationMock.put_env(:app, :key, 42)

      env = Env.new(nil, :app, :key, type: :integer)

      assert 42 == App.get_env(env)
    end

    test "when it's defined in a namespace, gets value" do
      ApplicationMock.put_env(:app, My.Custom.Namespace, key: 42)

      env = Env.new(My.Custom.Namespace, :app, :key, type: :integer)

      assert 42 == App.get_env(env)
    end

    test "when it's not defined, does not get the value" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert nil == App.get_env(env)
    end

    test "when cast is not possible, does not get the value" do
      ApplicationMock.put_env(:app, :key, 42.0)

      env = Env.new(nil, :app, :key, type: :integer)

      assert nil == App.get_env(env)
    end
  end
end
