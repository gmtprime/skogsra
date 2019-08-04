defmodule Skogsra.CacheTest do
  use ExUnit.Case

  alias Skogsra.Cache
  alias Skogsra.Env

  describe "get_env/1 and put_env/1" do
    test "when not set, errors" do
      env = Env.new(nil, :app, [:unexistent], [])

      assert :error == Cache.get_env(env)
    end

    test "when set, gets cached variable" do
      env = Env.new(nil, :app, [:a, :b], [])
      Cache.put_env(env, 42)

      assert {:ok, 42} == Cache.get_env(env)
    end
  end
end
