defmodule Skogsra.CoreTest do
  use ExUnit.Case

  alias Skogsra.Cache
  alias Skogsra.Core
  alias Skogsra.Env

  describe "put_env/1" do
    test "when cached is true, stores the variable" do
      env = Env.new(nil, :put_env_app, :key, default: 42)

      assert :ok = Core.put_env(env, 21)
      assert {:ok, 21} = Core.get_env(env)
    end

    test "when cached is false, errors" do
      env = Env.new(nil, :put_env_app, :key, cached: false)

      assert {:error, _} = Core.put_env(env, 42)
    end
  end

  describe "reload_env/1" do
    test "reloads a variable" do
      env = Env.new(nil, :reload_env_app, :key, default: 42)

      assert {:ok, 42} = Core.get_env(env)

      ApplicationMock.put_env(:reload_env_app, :key, 21)

      assert {:ok, 21} = Core.reload_env(env)
      assert {:ok, 21} = Core.get_env(env)
    end
  end

  describe "fsm_entry/1" do
    test "caches the variable" do
      env = Env.new(nil, :fsm_entry_app, :key, default: 42)

      assert {:ok, 42} = Core.fsm_entry(env)
      assert {:ok, 42} = Cache.get_env(env)
    end

    test "doesn't cache the variable" do
      env = Env.new(nil, :fsm_entry_app, :key, default: 42, cached: false)

      assert {:ok, 42} = Core.fsm_entry(env)
      assert :error = Cache.get_env(env)
    end
  end

  describe "get_cached/1" do
    test "when cached, returns cached value" do
      env = Env.new(nil, :cached_app, :key, [])
      Cache.put_env(env, 42)

      assert {:ok, 42} = Core.get_cached(env)
    end

    test "when not cached, caches it" do
      env = Env.new(nil, :not_cached_app, :key, default: 42)

      assert {:ok, 42} = Core.get_cached(env)

      assert {:ok, 42} = Cache.get_env(env)
    end
  end

  describe "get_system/1" do
    test "when there is no OS env, returns next" do
      options = [default: 42, skip_system: true, skip_config: true]
      env = Env.new(nil, :core_app, :key, options)

      assert {:ok, 42} = Core.get_system(env)
    end

    test "when there is OS env, returns it" do
      env = Env.new(nil, :core_app, :key, default: 42)

      SystemMock.put_env("CORE_APP_KEY", "21")

      assert {:ok, 21} = Core.get_system(env)
    end
  end

  describe "get_config/1" do
    test "when there is no config, returns default" do
      env = Env.new(nil, :core_app, :key, default: 42, skip_config: true)

      assert {:ok, 42} = Core.get_config(env)
    end

    test "when there is config, returns it" do
      env = Env.new(nil, :core_app, :key, [])

      ApplicationMock.put_env(:core_app, :key, 42)

      assert {:ok, 42} = Core.get_config(env)
    end
  end

  describe "get_default/1" do
    test "when variable is required and no default, errors" do
      env = Env.new(nil, :app, :key, required: true)

      assert {:error, _} = Core.get_default(env)
    end

    test "when default is present, returns it" do
      env = Env.new(nil, :app, :key, default: 42)

      assert {:ok, 42} = Core.get_default(env)
    end
  end
end
