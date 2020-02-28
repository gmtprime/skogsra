if Code.ensure_loaded?(Config.Provider) do
  defmodule Skogsra.Provider.JsonTest do
    use ExUnit.Case, async: true

    alias Skogsra.Provider.Json

    @fixtures "#{File.cwd!()}/test/support/fixtures/json"

    defp path(path) when is_binary(path), do: "#{@fixtures}/#{path}"

    setup do
      Application.ensure_all_started(:logger)
      Application.ensure_all_started(:jason)

      :ok
    end

    describe "init/1" do
      test "the path should be returned" do
        path = "/path/to/my/config/file.json"

        assert ^path = Json.init(path)
      end
    end

    describe "load/2" do
      test "reads a JSON without a namespace" do
        path = path("without_namespace.json")

        assert [
                 yggdrasil: [
                   postgres: [
                     password: "postgres_password",
                     username: "postgres_username"
                   ],
                   rabbitmq: [
                     password: "rabbitmq_password",
                     username: "rabbitmq_username"
                   ],
                   redis: [
                     password: "redis_password"
                   ]
                 ]
               ] = Json.load([], path)
      end

      test "reads a JSON with a module" do
        path = path("with_module.json")

        assert [
                 skogsra: [
                   "Elixir.Skogsra": [
                     application_module: "Application",
                     system_module: "System"
                   ]
                 ]
               ] = Json.load([], path)
      end

      test "reads a JSON with a namespace" do
        path = path("with_namespace.json")

        assert [
                 yggdrasil: [
                   "Elixir.MyApp.Namespace": [
                     postgres: [
                       password: "postgres_password",
                       username: "postgres_username"
                     ],
                     rabbitmq: [
                       password: "rabbitmq_password",
                       username: "rabbitmq_username"
                     ],
                     redis: [
                       password: "redis_password"
                     ]
                   ]
                 ]
               ] = Json.load([], path)
      end

      test "reads a JSON with several apps" do
        path = path("several_apps.json")

        assert [
                 yggdrasil: [
                   "Elixir.MyApp.Namespace": [
                     rabbitmq: [
                       hostname: "localhost",
                       password: "rabbitmq_password",
                       port: 7652,
                       username: "rabbitmq_username"
                     ]
                   ]
                 ],
                 skogsra: [
                   "Elixir.MyApp.Namespace": [
                     application_module: "App",
                     system_module: "Sys"
                   ]
                 ]
               ] = Json.load([], path)
      end

      test "returns same config if the configuration is not found" do
        path = path("unexistent_file.json")
        assert [] = Json.load([], path)
      end

      test "returns same config if an app name is not defined" do
        path = path("no_app_name.json")
        assert [] = Json.load([], path)
      end

      test "returns same config if the JSON config is invalid" do
        path = path("invalid_config.json")
        assert [] = Json.load([], path)
      end

      test "returns same config if JSON has an invalid namespace" do
        path = path("invalid_namespace.json")
        assert [] = Json.load([], path)
      end
    end
  end
end
