defmodule Skogsra.TestConfig do
  @moduledoc """
  Test config.
  """
  use Skogsra

  app_env :from_system, :my_app, :from_system,
    skip_config: true,
    type: :integer

  app_env :from_config, :my_app, :from_config,
    skip_system: true,
    type: :integer

  app_env :from_default, :my_app, :from_default,
    skip_system: true,
    skip_config: true,
    default: 42

  app_env :cached, :my_app, :cached,
    cached: true,
    default: 42

  app_env :not_cached, :my_app, :not_cached,
    cached: false,
    default: 42

  app_env :reloadable, :my_app, :reloadable, default: 42

  app_env :required, :my_app, :required,
    skip_system: true,
    required: true

  app_env :not_required, :my_app, :not_required,
    skip_system: true,
    required: false

  app_env :custom_type, :my_app, :custom_type, type: Skogsra.IntegerList
end
