defmodule SkogsraTest do
  use ExUnit.Case, async: true

  #######
  # Tests

  #################
  # Tests for macro

  describe "app_env/4" do
    defmodule TestVars do
      use Skogsra

      app_env :from_system, :my_app, :from_system, type: :integer
      app_env :from_config, :my_app, :from_config, type: :integer
      app_env :from_default, :my_app, :from_default, default: 42

      app_env :reloadable, :my_app, :reloadable, default: 42
      app_env :reloadable_with_namespace, :my_app, :reloadable_with_namespace,
        default: 42

      app_env :required, :my_app, :required, type: :integer, required: true
    end

    test "gets variable's value from system" do
      SystemMock.put_env("MY_APP_FROM_SYSTEM", "42")
      assert {:ok, 42} = TestVars.from_system()
    end

    test "gets variable's value from system for a namespace" do
      SystemMock.put_env("NAMESPACE_MY_APP_FROM_SYSTEM", "42")
      assert {:ok, 42} = TestVars.from_system(Namespace)
    end

    test "gets variable's value from config" do
      ApplicationMock.put_env(:my_app, :from_config, 42)
      assert {:ok, 42} = TestVars.from_config()
    end

    test "gets variable's value from config for a namespace" do
      ApplicationMock.put_env(:my_app, Namespace, from_config: 42)
      assert {:ok, 42} = TestVars.from_config(Namespace)
    end

    test "gets variable's value from default" do
      assert {:ok, 42} = TestVars.from_default()
    end

    test "gets variable's value from default for a namespace" do
      assert {:ok, 42} = TestVars.from_default(Namespace)
    end

    test "when required value not found, fails" do
      assert_raise RuntimeError, fn -> TestVars.required!() end
    end

    test "reloads variable's value" do
      assert {:ok, 42} = TestVars.reloadable()
      assert :ok = TestVars.put_reloadable(21)
      assert {:ok, 21} = TestVars.reloadable()
    end

    test "reloads variable's value for a namespace" do
      assert {:ok, 42} = TestVars.reloadable_with_namespace(Namespace)
      assert :ok = TestVars.put_reloadable_with_namespace(21, Namespace)
      assert {:ok, 21} = TestVars.reloadable_with_namespace(Namespace)
    end
  end
end
