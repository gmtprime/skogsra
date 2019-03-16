defmodule Skogsra.Application do
  @moduledoc false
  use Application

  alias Skogsra.Cache

  @impl true
  def start(_type, _args) do
    _ = Cache.new()

    options = [strategy: :one_for_one, name: Skogsra.Supervisor]
    Supervisor.start_link([], options)
  end
end
