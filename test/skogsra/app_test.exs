defmodule Skogsra.AppTest do
  use ExUnit.Case, async: true

  alias Skogsra.App
  alias Skogsra.Env

  describe "get_env/1" do
    test "when it's defined, gets value" do
      ApplicationMock.put_env(:app, :key, 42)

      env = Env.new(nil, :app, :key, type: :integer)

      assert {:ok, 42} = App.get_env(env)
    end

    test "when it's defined in a namespace, gets value" do
      ApplicationMock.put_env(:app, My.Custom.Namespace, key: 42)

      env = Env.new(My.Custom.Namespace, :app, :key, type: :integer)

      assert {:ok, 42} = App.get_env(env)
    end

    test "when it's not defined, does not get the value" do
      env = Env.new(nil, :app, [:a, :b], [])

      assert {:ok, nil} = App.get_env(env)
    end
  end
end
