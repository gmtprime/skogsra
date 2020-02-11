defmodule Skogsra.DocsTest do
  use ExUnit.Case, async: true

  alias Skogsra.Docs

  describe "gen_full_docs/6" do
    test "when docs are false, returns false" do
      assert false ==
               Docs.gen_full_docs(
                 __MODULE__,
                 :function,
                 :app,
                 [:key],
                 [],
                 false
               )
    end

    test "when docs are binary, returns binary" do
      docs = Docs.gen_full_docs(__MODULE__, :function, :app, [:key], [], "")

      assert is_binary(docs)
    end
  end

  describe "gen_short_docs/6" do
    test "when docs are false, returns false" do
      assert false == Docs.gen_short_docs(__MODULE__, :function, false)
    end

    test "when docs are binary, returns binary" do
      docs = Docs.gen_short_docs(__MODULE__, :function, "")

      assert is_binary(docs)
    end
  end

  describe "gen_reload_docs/6" do
    test "when docs are false, returns false" do
      assert false == Docs.gen_reload_docs(__MODULE__, :function, false)
    end

    test "when docs are binary, returns binary" do
      docs = Docs.gen_reload_docs(__MODULE__, :function, "")

      assert is_binary(docs)
    end
  end

  describe "gen_put_docs/6" do
    test "when docs are false, returns false" do
      assert false == Docs.gen_put_docs(__MODULE__, :function, false)
    end

    test "when docs are binary, returns binary" do
      docs = Docs.gen_put_docs(__MODULE__, :function, "")

      assert is_binary(docs)
    end
  end
end
