defmodule Skogsra.Application do
  @moduledoc false
  use Application

  @cache :skogsra_cache

  @impl true
  def start(_type, _args) do
    opts = [:set, :named_table, :public, read_concurrency: true]
    _ = :ets.new(@cache, opts)

    options = [strategy: :one_for_one, name: Skogsra.Supervisor]
    Supervisor.start_link([], options)
  end
end
