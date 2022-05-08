if Code.ensure_loaded?(Config.Provider) do
  defmodule Skogsra.Provider.YamlTest do
    use ExUnit.Case, async: true

    alias Skogsra.Provider.Yaml

    @fixtures "#{File.cwd!()}/test/support/fixtures/yaml"

    defp path(path) when is_binary(path), do: "#{@fixtures}/#{path}"

    setup do
      Application.ensure_all_started(:logger)
      Application.ensure_all_started(:yamerl)

      :ok
    end

    describe "init/1" do
      test "the path should be returned" do
        path = "/path/to/my/config/file.yml"

        assert ^path = Yaml.init(path)
      end
    end

    describe "load/2" do
      test "reads a YAML without a namespace" do
        path = path("without_namespace.yml")

        assert [
                 yggdrasil: [
                   rabbitmq: [
                     username: "rabbitmq_username",
                     password: "rabbitmq_password"
                   ],
                   postgres: [
                     username: "postgres_username",
                     password: "postgres_password"
                   ],
                   redis: [
                     password: "redis_password"
                   ]
                 ]
               ] = Yaml.load([], path)
      end

      test "reads a YAML with a module" do
        path = path("with_module.yml")

        assert [
                 skogsra: [
                   {
                     Skogsra,
                     [
                       system_module: "System",
                       application_module: "Application"
                     ]
                   }
                 ]
               ] = Yaml.load([], path)
      end

      test "reads a YAML with a namespace" do
        path = path("with_namespace.yml")

        assert [
                 yggdrasil: [
                   {
                     MyApp.Namespace,
                     [
                       rabbitmq: [
                         username: "rabbitmq_username",
                         password: "rabbitmq_password"
                       ],
                       postgres: [
                         username: "postgres_username",
                         password: "postgres_password"
                       ],
                       redis: [
                         password: "redis_password"
                       ]
                     ]
                   }
                 ]
               ] = Yaml.load([], path)
      end

      test "reads a YAML with several apps" do
        path = path("several_apps.yml")

        assert [
                 skogsra: [
                   {
                     MyApp.Namespace,
                     [
                       system_module: "Sys",
                       application_module: "App"
                     ]
                   }
                 ],
                 yggdrasil: [
                   {
                     MyApp.Namespace,
                     [
                       rabbitmq: [
                         username: "rabbitmq_username",
                         password: "rabbitmq_password",
                         hostname: "localhost",
                         port: 7652
                       ]
                     ]
                   }
                 ]
               ] = Yaml.load([], path)
      end

      test "reads a YAML with duplicate apps and merges them" do
        path = path("duplicate_apps.yml")

        assert [
                 yggdrasil: [
                   {
                     MyApp.Namespace,
                     [
                       postgres: [
                         username: "postgres_username",
                         password: "postgres_password",
                         database: "postgres_database",
                         hostname: "localhost",
                         port: 5432
                       ],
                       rabbitmq: [
                         username: "rabbitmq_username",
                         password: "rabbitmq_password",
                         hostname: "localhost",
                         port: 7652
                       ]
                     ]
                   },
                   {
                     MyApp.OtherNamespace,
                     [
                       postgres: [
                         username: "postgres_username",
                         password: "postgres_password",
                         database: "postgres_database",
                         hostname: "localhost",
                         port: 5432
                       ]
                     ]
                   }
                 ]
               ] = Yaml.load([], path)
      end

      test "returns same config if the configuration is not found" do
        path = path("unexistent_file.yml")
        assert [] = Yaml.load([], path)
      end

      test "reads normal lists" do
        path = path("with_lists.yml")

        assert [
                 my_app: [
                   {
                     MyApp.Endpoint,
                     [
                       check_origin: [
                         "mydomain",
                         "www.mydomain",
                         "subdomain.mydomain"
                       ]
                     ]
                   }
                 ]
               ] = Yaml.load([], path)
      end

      test "returns same config if an app name is not defined" do
        path = path("no_app_name.yml")
        assert [] = Yaml.load([], path)
      end

      test "returns same config if the YAML config is invalid" do
        path = path("invalid_config.yml")
        assert [] = Yaml.load([], path)
      end

      test "returns same config if YAML has an invalid namespace" do
        path = path("invalid_namespace.yml")
        assert [] = Yaml.load([], path)
      end
    end
  end
end
