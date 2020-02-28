defmodule Skogsra.Sys do
  @moduledoc """
  This module defines the functions to get environment variables from the OS.
  """
  use Skogsra.Binding

  alias Skogsra.Env

  ##########
  # Callback

  @impl Skogsra.Binding
  def get_env(env, config)

  def get_env(%Env{} = env, _config) do
    module = Application.get_env(:skogsra, :system_module, System)
    name = Env.os_env(env)
    value = apply(module, :get_env, [name])

    {:ok, value}
  end
end
