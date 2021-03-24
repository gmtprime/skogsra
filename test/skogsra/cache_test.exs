defmodule Skogsra.CacheTest do
  use ExUnit.Case, async: true

  alias Skogsra.Cache
  alias Skogsra.Env

  describe "get_env/1 and put_env/1" do
    test "when not set, errors" do
      env =
        Env.new(%{
          app_name: :app,
          module: __MODULE__,
          function: :function,
          keys: [:unexistent],
          options: []
        })

      assert :error == Cache.get_env(env)
    end

    test "when set, gets cached variable" do
      env =
        Env.new(%{
          app_name: :app,
          module: __MODULE__,
          function: :function,
          keys: [:a, :b],
          options: []
        })

      Cache.put_env(env, 42)

      assert {:ok, 42} == Cache.get_env(env)
    end
  end
end
