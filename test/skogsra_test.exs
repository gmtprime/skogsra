defmodule SkogsraTest do
  use ExUnit.Case, async: true

  describe "app_env/4" do
    defmodule AppEnv.NoOptionsConfig do
      use Skogsra

      app_env :no_options, :my_app, :no_options
    end

    defmodule AppEnv.FromSystemConfig do
      use Skogsra

      app_env :from_system, :my_app, :from_system,
        binding_skip: [:config],
        type: :integer
    end

    defmodule AppEnv.FromAppConfig do
      use Skogsra

      app_env :from_config, :my_app, :from_config,
        binding_skip: [:system],
        type: :integer
    end

    defmodule AppEnv.FromDefaultConfig do
      use Skogsra

      app_env :from_default, :my_app, :from_default,
        binding_skip: [:system, :config],
        default: 42
    end

    defmodule AppEnv.CachedConfig do
      use Skogsra

      app_env :cached, :my_app, :cached,
        cached: true,
        default: 42
    end

    defmodule AppEnv.NotCachedConfig do
      use Skogsra

      app_env :not_cached, :my_app, :not_cached,
        cached: false,
        default: 42
    end

    defmodule AppEnv.ReloadableConfig do
      use Skogsra

      app_env :reloadable, :my_app, :reloadable, default: 42
    end

    defmodule AppEnv.RequiredConfig do
      use Skogsra

      app_env :required, :my_app, :required,
        binding_skip: [:system],
        required: true
    end

    defmodule AppEnv.CustomTypeConfig do
      use Skogsra

      app_env :custom_type, :my_app, :custom_type, type: Skogsra.IntegerList
    end

    defmodule AppEnv.FromJsonConfig do
      use Skogsra

      app_env :from_json, :my_app, :from_json,
        os_env: "MY_JSON_VALUE",
        binding_order: [:system, :config, Skogsra.JsonBinding],
        config_path: "./test/support/fixtures/config.json",
        default: 42
    end

    test "when no options are defined and value exists, gets value" do
      SystemMock.put_env("MY_APP_NO_OPTIONS", "Foo")

      assert {:ok, "Foo"} = AppEnv.NoOptionsConfig.no_options()
    end

    test "when OS env variable exists, gets value" do
      SystemMock.put_env("MY_APP_FROM_SYSTEM", "42")

      assert {:ok, 42} = AppEnv.FromSystemConfig.from_system()
    end

    test "when OS env variable exists for a namespace, gets value" do
      SystemMock.put_env("NAMESPACE_MY_APP_FROM_SYSTEM", "42")

      assert {:ok, 42} = AppEnv.FromSystemConfig.from_system(Namespace)
    end

    test "when app config variable exists, gets value" do
      ApplicationMock.put_env(:my_app, :from_config, 42)

      assert {:ok, 42} = AppEnv.FromAppConfig.from_config()
    end

    test "when app config variable exists for a namespace, gets value" do
      ApplicationMock.put_env(:my_app, Namespace, from_config: 42)

      assert {:ok, 42} = AppEnv.FromAppConfig.from_config(Namespace)
    end

    test "when default value it's defined, gets value" do
      assert {:ok, 42} = AppEnv.FromDefaultConfig.from_default()
    end

    test "when default value it's defined for a namespace, gets value" do
      assert {:ok, 42} = AppEnv.FromDefaultConfig.from_default(Namespace)
    end

    test "when variable is cached, gets cached value" do
      Skogsra.Cache.put_env(AppEnv.CachedConfig.__cached__(), 21)

      assert {:ok, 21} = AppEnv.CachedConfig.cached()
    end

    test "when variable is cached for a namespace, gets cached value" do
      Skogsra.Cache.put_env(AppEnv.CachedConfig.__cached__(Namespace), 21)

      assert {:ok, 21} = AppEnv.CachedConfig.cached(Namespace)
    end

    test "when variable is not cached, gets value from source" do
      Skogsra.Cache.put_env(AppEnv.NotCachedConfig.__not_cached__(), 21)

      assert {:ok, 42} = AppEnv.NotCachedConfig.not_cached()
    end

    test "when variable is not cached for a namespace, gets value from source" do
      Skogsra.Cache.put_env(
        AppEnv.NotCachedConfig.__not_cached__(Namespace),
        21
      )

      assert {:ok, 42} = AppEnv.NotCachedConfig.not_cached(Namespace)
    end

    test "when variable is cached, reloads variable's value" do
      assert :ok = AppEnv.ReloadableConfig.put_reloadable(21)
      assert {:ok, 21} = AppEnv.ReloadableConfig.reloadable()
    end

    test "when varable is cached for a namespace, reloads variable's value" do
      assert :ok = AppEnv.ReloadableConfig.put_reloadable(84, Namespace)
      assert {:ok, 84} = AppEnv.ReloadableConfig.reloadable(Namespace)
    end

    test "when required value not found, fails" do
      assert_raise RuntimeError, fn -> AppEnv.RequiredConfig.required!() end
    end

    test "when required value not found for a namespace, fails" do
      assert_raise RuntimeError, fn ->
        AppEnv.RequiredConfig.required!(Namespace)
      end
    end

    test "when required value not found, errors" do
      assert {:error, _} = AppEnv.RequiredConfig.required()
    end

    test "when required value not found for a namespace, errors" do
      assert {:error, _} = AppEnv.RequiredConfig.required()
    end

    test "when custom type is used, is casted correctly" do
      SystemMock.put_env("MY_APP_CUSTOM_TYPE", "1,2,    3")

      assert {:ok, [1, 2, 3]} = AppEnv.CustomTypeConfig.custom_type()
    end

    test "when custom type is used for a namespace, is casted correctly" do
      SystemMock.put_env("NAMESPACE_MY_APP_CUSTOM_TYPE", "4,5,    6")

      assert {:ok, [4, 5, 6]} = AppEnv.CustomTypeConfig.custom_type(Namespace)
    end

    test "when is loaded from a binding, gets the value" do
      assert {:ok, 21} = AppEnv.FromJsonConfig.from_json()
    end
  end

  describe "validate" do
    defmodule Validate.EmptyConfig do
      use Skogsra
    end

    defmodule Validate.NoRequiredConfig do
      use Skogsra

      app_env :not_required, :validation_app, :not_required,
        binding_skip: [:system],
        required: false

      app_env :not_required_either, :validation_app, :not_required_either
    end

    defmodule Validate.RequiredConfig do
      use Skogsra

      app_env :required, :validation_app, :required, required: true
    end

    defmodule Validate.MissingRequiredConfig do
      use Skogsra

      app_env :missing_required, :validation_app, :missing_required,
        required: true
    end

    defmodule Validate.TypedRequiredConfig do
      use Skogsra

      app_env :int_required, :validation_app, :int_required,
        type: :integer,
        required: true
    end

    test "with empty config, succeeds" do
      assert :ok = Validate.EmptyConfig.validate()
      assert :ok = Validate.EmptyConfig.validate!()
    end

    test "with config with no required values, succeeds" do
      assert :ok = Validate.NoRequiredConfig.validate()
      assert :ok = Validate.NoRequiredConfig.validate!()
    end

    test "when required values are found, succeeds" do
      SystemMock.put_env("VALIDATION_APP_REQUIRED", "42")

      assert :ok = Validate.RequiredConfig.validate()
      assert :ok = Validate.RequiredConfig.validate!()
    end

    test "when required value not found, fails" do
      assert_raise RuntimeError, fn ->
        Validate.MissingRequiredConfig.validate!()
      end
    end

    test "when required value not found for a namespace, fails" do
      assert_raise RuntimeError, fn ->
        Validate.MissingRequiredConfig.validate!(Namespace)
      end
    end

    test "when required value not found, errors" do
      assert {:error, _} = Validate.MissingRequiredConfig.validate()
    end

    test "when required value not found for a namespace, errors" do
      assert {:error, _} = Validate.MissingRequiredConfig.validate(Namespace)
    end

    test "when required value has incorrect type, fails" do
      SystemMock.put_env("VALIDATION_APP_INT_REQUIRED", "foo")

      assert_raise RuntimeError, fn ->
        Validate.TypedRequiredConfig.validate!()
      end
    end
  end
end
