defmodule Skogsra.CacheTest do
  use ExUnit.Case

  alias Skogsra.Cache
  alias Skogsra.Env

  setup do
    cache = :ets.new(:skogsra_test, [])
    {:ok, [cache: cache]}
  end

  describe "get_env/1 and put_env/1" do
    test "when not set, errors", %{cache: cache} do
      env = Env.new(cache, nil, :app, [:a, :b], [])

      assert :error == Cache.get_env(env)
    end

    test "when set, gets cached variable", %{cache: cache} do
      env = Env.new(cache, nil, :app, [:a, :b], [])
      Cache.put_env(env, 42)

      assert {:ok, 42} == Cache.get_env(env)
    end
  end
end
