defmodule Skogsra.Provider.YamlTest do
  use ExUnit.Case, async: true

  alias Skogsra.Provider.Yaml

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
      path = "./test/support/fixtures/without_namespace.yml"
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

    test "reads a YAML with a namespace" do
      path = "./test/support/fixtures/with_namespace.yml"
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
      path = "./test/support/fixtures/several_apps.yml"
      assert [
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
        ],
        skogsra: [
          {
            MyApp.Namespace,
            [
              system_module: "Sys",
              application_module: "App"
            ]
          }
        ]
      ] = Yaml.load([], path)
    end

    test "returns same config if the configuration is not found" do
      path = "./test/support/fixtures/unexistent_file.yml"
      assert [] = Yaml.load([], path)
    end

    test "returns same config if an app name is not defined" do
      path = "./test/support/fixtures/no_app_name.yml"
      assert [] = Yaml.load([], path)
    end

    test "returns same config if the YAML config is invalid" do
      path = "./test/support/fixtures/invalid_config.yml"
      assert [] = Yaml.load([], path)
    end

    test "returns same config if YAML has an invalid namespace" do
      path = "./test/support/fixtures/invalid_namespace.yml"
      assert [] = Yaml.load([], path)
    end
  end
end
