defmodule Skogsra.SysTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env
  alias Skogsra.Sys

  describe "get_env/1" do
    setup do
      name = "VAR#{make_ref() |> :erlang.phash2()}"
      env = Env.new(nil, :system_app, :key, os_env: name)

      {:ok, env: env}
    end

    test "when variable is not defined, returns nil", %{env: env} do
      assert {:ok, nil} == Sys.get_env(env, nil)
    end

    test "when variable is defined, returns value", %{env: env} do
      SystemMock.put_env(env.options[:os_env], "42")

      assert {:ok, "42"} = Sys.get_env(env, nil)
    end
  end
end
