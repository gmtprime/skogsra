defmodule SkogsraTest do
  use ExUnit.Case

  defmodule TestEnv do
    use Skogsra

    system_env :skogsra_static_var,
      default: "default"

    system_env :skogsra_dynamic_var,
      static: false,
      default: "default"

    system_env :skogsra_explicit_type,
      static: false,
      type: :integer,
      default: "42"

    system_env :skogsra_implicit_type,
      static: false,
      default: 42

    app_env :skogsra_app_static_var, :skogsra, :app_static_var,
      default: "default"

    app_env :skogsra_app_dynamic_var, :skogsra, :app_dynamic_var,
      static: false,
      default: "default"

      app_env :skogsra_app_explicit_type, :skogsra, :app_explicit_type,
        static: false,
        type: :integer,
        default: "42"

      app_env :skogsra_app_implicit_type, :skogsra, :app_implicit_type,
        static: false,
        default: 42
  end

  test "system_env static" do
    System.put_env("SKOGSRA_STATIC_VAR", "custom")

    assert TestEnv.skogsra_static_var == "default"

    System.delete_env("SKOGSRA_STATIC_VAR")
  end

  test "system_env dynamic" do
    System.put_env("SKOGSRA_DYNAMIC_VAR", "custom")

    assert TestEnv.skogsra_dynamic_var == "custom"

    System.delete_env("SKOGSRA_DYNAMIC_VAR")
  end

  test "system_env explicit type" do
    assert TestEnv.skogsra_explicit_type == 42
    System.put_env("SKOGSRA_EXPLICIT_TYPE", "41")
    assert TestEnv.skogsra_explicit_type == 41
    System.delete_env("SKOGSRA_EXPLICIT_TYPE")
  end

  test "system_env implicit type" do
    assert TestEnv.skogsra_implicit_type == 42
    System.put_env("SKOGSRA_IMPLICIT_TYPE", "41")
    assert TestEnv.skogsra_implicit_type == 41
    System.delete_env("SKOGSRA_IMPLICIT_TYPE")
  end

  test "app_env static var" do
    System.put_env("SKOGSRA_APP_STATIC_VAR", "custom")
    Application.put_env(:skogsra, :app_static_var, "custom")

    assert TestEnv.skogsra_app_static_var == "default"

    Application.delete_env(:skogsra, :app_static_var)
    System.delete_env("SKOGSRA_APP_STATIC_VAR")
  end

  test "app_env dynamic var" do
    assert TestEnv.skogsra_app_dynamic_var == "default"

    Application.put_env(:skogsra, :app_dynamic_var, "custom_app")
    assert TestEnv.skogsra_app_dynamic_var == "custom_app"
    Application.delete_env(:skogsra, :app_dynamic_var)

    System.put_env("SKOGSRA_APP_DYNAMIC_VAR", "custom_env")
    assert TestEnv.skogsra_app_dynamic_var == "custom_env"
    System.delete_env("SKOGSRA_APP_DYNAMIC_VAR")
  end

  test "app_env explicit type" do
    assert TestEnv.skogsra_app_explicit_type == 42

    Application.put_env(:skogsra, :app_explicit_type, 41)
    assert TestEnv.skogsra_app_explicit_type == 41
    Application.delete_env(:skogsra, :app_explicit_type)

    System.put_env("SKOGSRA_APP_EXPLICIT_TYPE", "40")
    assert TestEnv.skogsra_app_explicit_type == 40
    System.delete_env("SKOGSRA_APP_EXPLICIT_TYPE")
  end

  test "app_env implicit type" do
    assert TestEnv.skogsra_app_implicit_type == 42

    Application.put_env(:skogsra, :app_implicit_type, "41")
    assert TestEnv.skogsra_app_implicit_type == 41
    Application.delete_env(:skogsra, :app_implicit_type)

    System.put_env("SKOGSRA_APP_IMPLICIT_TYPE", "40")
    assert TestEnv.skogsra_app_implicit_type == 40
    System.delete_env("SKOGSRA_APP_IMPLICIT_TYPE")
  end

  test "get_env" do
    assert Skogsra.get_env("SKOGSRA_GET_ENV", 42) == 42

    System.put_env("SKOGSRA_GET_ENV", "41")
    assert Skogsra.get_env("SKOGSRA_GET_ENV", 42) == 41
    System.delete_env("SKOGSRA_GET_ENV")
  end

  test "get_env_as" do
    assert Skogsra.get_env_as(:integer, "SKOGSRA_GET_ENV_AS", "42") == 42

    System.put_env("SKOGSRA_GET_ENV_AS", "41")
    assert Skogsra.get_env_as(:integer, "SKOGSRA_GET_ENV_AS", "42") == 41
    System.delete_env("SKOGSRA_GET_ENV_AS")
  end

  test "get_app_env" do
    opts = [default: "42", domain: Skogsra.Domain, type: :integer]
    assert Skogsra.get_app_env("SKOGSRA_GET_APP_ENV", :skogsra, :key, opts) == 42

    Application.put_env(:skogsra, Skogsra.Domain, [key: "41"])
    assert Skogsra.get_app_env("SKOGSRA_GET_APP_ENV", :skogsra, :key, opts) == 41
    Application.delete_env(:skogsra, Skogsra)

    opts = [default: "42", type: :integer]

    Application.put_env(:skogsra, :key, "40")
    assert Skogsra.get_app_env("SKOGSRA_GET_APP_ENV", :skogsra, :key, opts) == 40
    Application.delete_env(:skogsra, :key)

    System.put_env("SKOGSRA_GET_APP_ENV", "39")
    assert Skogsra.get_app_env("SKOGSRA_GET_APP_ENV", :skogsra, :key, opts) == 39
    System.delete_env("SKOGSRA_GET_ENV_AS")
  end

  test "type?" do
    assert Skogsra.type?("binary") == :any
    assert Skogsra.type?(42) == :integer
    assert Skogsra.type?(42.0) == :float
    assert Skogsra.type?(true) == :boolean
    assert Skogsra.type?(:atom) == :atom
  end
end
