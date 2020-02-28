defmodule SkogsraTest do
  use ExUnit.Case, async: true

  alias Skogsra.TestConfig

  describe "app_env/4" do
    test "when no options are defined and value exists, gets value" do
      SystemMock.put_env("MY_APP_NO_OPTIONS", "Foo")

      assert {:ok, "Foo"} = TestConfig.no_options()
    end

    test "when OS env variable exists, gets value" do
      SystemMock.put_env("MY_APP_FROM_SYSTEM", "42")

      assert {:ok, 42} = TestConfig.from_system()
    end

    test "when OS env variable exists for a namespace, gets value" do
      SystemMock.put_env("NAMESPACE_MY_APP_FROM_SYSTEM", "42")

      assert {:ok, 42} = TestConfig.from_system(Namespace)
    end

    test "when app config variable exists, gets value" do
      ApplicationMock.put_env(:my_app, :from_config, 42)

      assert {:ok, 42} = TestConfig.from_config()
    end

    test "when app config variable exists for a namespace, gets value" do
      ApplicationMock.put_env(:my_app, Namespace, from_config: 42)

      assert {:ok, 42} = TestConfig.from_config(Namespace)
    end

    test "when default value it's defined, gets value" do
      assert {:ok, 42} = TestConfig.from_default()
    end

    test "when default value it's defined for a namespace, gets value" do
      assert {:ok, 42} = TestConfig.from_default(Namespace)
    end

    test "when variable is cached, gets cached value" do
      Skogsra.Cache.put_env(TestConfig.__cached__(), 21)

      assert {:ok, 21} = TestConfig.cached()
    end

    test "when variable is cached for a namespace, gets cached value" do
      Skogsra.Cache.put_env(TestConfig.__cached__(Namespace), 21)

      assert {:ok, 21} = TestConfig.cached(Namespace)
    end

    test "when variable is not cached, gets value from source" do
      Skogsra.Cache.put_env(TestConfig.__not_cached__(), 21)

      assert {:ok, 42} = TestConfig.not_cached()
    end

    test "when variable is not cached for a namespace, gets value from source" do
      Skogsra.Cache.put_env(TestConfig.__not_cached__(Namespace), 21)

      assert {:ok, 42} = TestConfig.not_cached(Namespace)
    end

    test "when variable is cached, reloads variable's value" do
      assert :ok = TestConfig.put_reloadable(21)
      assert {:ok, 21} = TestConfig.reloadable()
    end

    test "when varable is cached for a namespace, reloads variable's value" do
      assert :ok = TestConfig.put_reloadable(84, Namespace)
      assert {:ok, 84} = TestConfig.reloadable(Namespace)
    end

    test "when required value not found, fails" do
      assert_raise RuntimeError, fn -> TestConfig.required!() end
    end

    test "when required value not found for a namespace, fails" do
      assert_raise RuntimeError, fn -> TestConfig.required!(Namespace) end
    end

    test "when required value not found, errors" do
      assert {:error, _} = TestConfig.required()
    end

    test "when required value not found for a namespace, errors" do
      assert {:error, _} = TestConfig.required()
    end

    test "when custom type is used, is casted correctly" do
      SystemMock.put_env("MY_APP_CUSTOM_TYPE", "1,2,    3")

      assert {:ok, [1, 2, 3]} = TestConfig.custom_type()
    end

    test "when custom type is used for a namespace, is casted correctly" do
      SystemMock.put_env("NAMESPACE_MY_APP_CUSTOM_TYPE", "4,5,    6")

      assert {:ok, [4, 5, 6]} = TestConfig.custom_type(Namespace)
    end

    test "when is loaded from a binding, gets the value" do
      assert {:ok, 21} = TestConfig.from_json()
    end
  end
end
