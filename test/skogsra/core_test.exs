defmodule Skogsra.CoreTest do
  use ExUnit.Case, async: true

  alias Skogsra.Cache
  alias Skogsra.Core
  alias Skogsra.Env

  describe "get_env/1" do
    test "when no cache available, can skip cache" do
      options = [default: 42, cached: false, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      Cache.put_env(env, 21)
      assert {:ok, 42} = Core.get_env(env)
    end

    test "when cache available, cannot skip cache" do
      options = [default: 42, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      Cache.put_env(env, 21)
      assert {:ok, 21} = Core.get_env(env)
    end

    test "when value is required with just one key, returns error message" do
      options = [required: true, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      expected = "Variable key in app core_app is undefined"

      assert {:error, ^expected} = Core.get_env(env)
    end

    test "when value is required with several keys, returns error message" do
      options = [required: true, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, [:first, :second], options)

      expected = "Variables first, second in app core_app are undefined"

      assert {:error, ^expected} = Core.get_env(env)
    end
  end

  describe "get_env!/1" do
    test "when exists, returns value" do
      unique = "VAR#{make_ref() |> :erlang.phash2()}"
      options = [default: 42, os_env: unique, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      assert 42 = Core.get_env!(env)
    end

    test "when doesn't exist, returns nil" do
      options = [binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      assert is_nil(Core.get_env!(env))
    end

    test "when doesn't exist and it's required, fails" do
      options = [required: true, binding_skip: [:system, :config]]
      env = Env.new(nil, :core_app, :key, options)

      assert_raise RuntimeError, fn ->
        Core.get_env!(env)
      end
    end
  end

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

  describe "fsm_entry/1 for system" do
    setup do
      name = "VAR#{make_ref() |> :erlang.phash2()}"
      options = [default: 42, os_env: name, binding_skip: [:config]]
      env = Env.new(nil, :core_app, :key, options)

      {:ok, env: env, options: options}
    end

    test "when there is no OS env, returns default", %{env: env} do
      assert {:ok, 42} = Core.fsm_entry(env)
    end

    test "when there is OS env, returns it", %{env: env, options: options} do
      SystemMock.put_env(options[:os_env], "21")

      assert {:ok, 21} = Core.fsm_entry(env)
    end
  end

  describe "fsm_entry/1 for config" do
    setup do
      options = [default: 42, binding_skip: [:system]]
      env = Env.new(nil, :core_app, :key, options)

      {:ok, env: env, options: options}
    end

    test "when there is no app config, returns default", %{env: env} do
      assert {:ok, 42} = Core.fsm_entry(env)
    end

    test "when there is app config, returns it", %{env: env} do
      ApplicationMock.put_env(:core_app, :key, 21)

      assert {:ok, 21} = Core.fsm_entry(env)
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
