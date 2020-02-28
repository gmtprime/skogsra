defmodule Skogsra.TestConfig do
  @moduledoc """
  Test config.
  """
  use Skogsra

  app_env :no_options, :my_app, :no_options

  app_env :from_system, :my_app, :from_system,
    binding_skip: [:config],
    type: :integer

  app_env :from_config, :my_app, :from_config,
    binding_skip: [:system],
    type: :integer

  app_env :from_default, :my_app, :from_default,
    binding_skip: [:system, :config],
    default: 42

  app_env :cached, :my_app, :cached,
    cached: true,
    default: 42

  app_env :not_cached, :my_app, :not_cached,
    cached: false,
    default: 42

  app_env :reloadable, :my_app, :reloadable, default: 42

  app_env :required, :my_app, :required,
    binding_skip: [:system],
    required: true

  app_env :not_required, :my_app, :not_required,
    binding_skip: [:system],
    required: false

  app_env :custom_type, :my_app, :custom_type, type: Skogsra.IntegerList

  app_env :from_json, :my_app, :from_json,
    os_env: "MY_JSON_VALUE",
    binding_order: [:system, :config, Skogsra.JsonBinding],
    config_path: "./test/support/fixtures/config.json",
    default: 42
end
