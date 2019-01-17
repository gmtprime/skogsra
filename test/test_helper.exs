defmodule SystemMock do
  @cache :system_mock

  def start_link do
    Application.put_env(:skogsra, :system_module, __MODULE__)
    opts = [:set, :public, :named_table, read_concurrency: true]
    Agent.start_link(fn -> :ets.new(@cache, opts) end)
  end

  def get_key(name) do
    pid = self()
    :erlang.phash2({pid, name})
  end

  def put_env(name, value) do
    key = get_key(name)
    :ets.insert(@cache, {key, value})
  end

  def get_env(name) do
    key = get_key(name)
    case :ets.lookup(@cache, key) do
      [{^key, value} | _] ->
        value
      _ ->
        nil
    end
  end
end

defmodule ApplicationMock do
  @cache :application_mock

  def start_link do
    Application.put_env(:skogsra, :application_module, __MODULE__)
    opts = [:set, :public, :named_table, read_concurrency: true]
    Agent.start_link(fn -> :ets.new(@cache, opts) end)
  end

  def get_key(app_name, property) do
    pid = self()
    :erlang.phash2({pid, app_name, property})
  end

  def put_env(app_name, property, value) do
    key = get_key(app_name, property)
    :ets.insert(@cache, {key, value})
  end

  def get_env(app_name, property) do
    key = get_key(app_name, property)
    case :ets.lookup(@cache, key) do
      [{^key, value} | _] ->
        value
      _ ->
        nil
    end
  end
end

{:ok, _} = SystemMock.start_link()
{:ok, _} = ApplicationMock.start_link()

ExUnit.start()
