defmodule Skogsra.EnvTest do
  use ExUnit.Case

  alias Skogsra.Env

  describe "new/2" do
    test "adds default options" do
      %Env{options: options} = Env.new(nil, :app, :key, [])

      assert options[:skip_system] == false
      assert options[:skip_config] == false
      assert options[:required] == false
      assert options[:cached] == true
    end

    test "converts single key to a list" do
      assert %Env{keys: [:key]} = Env.new(nil, :app, :key, [])
    end

    test "sets namespace" do
      assert %Env{namespace: Test} = Env.new(nil, :app, :key, namespace: Test)
    end
  end
end
