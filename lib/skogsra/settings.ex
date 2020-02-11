defmodule Skogsra.Settings do
  @moduledoc """
  Settings for Skogsra (only testing purposes).
  """
  use Skogsra

  @envdoc """
  Changes `System` for a custom module (only for testing purposes).
  """
  app_env :system_module, :skogsra, :system_module,
    default: System,
    type: :module,
    skip_system: true

  @envdoc """
  Changes `Application` for a custom module (only for testing purposes).
  """
  app_env :application_module, :skogsra, :application_module,
    default: Application,
    type: :module,
    skip_system: true
end
