defmodule Skogsra.TypeTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env
  alias Skogsra.Type

  describe "cast/2" do
    test "casts a binary" do
      env = %Env{options: [type: :binary]}

      assert {:ok, "42"} = Type.cast(env, 42)
    end

    test "casts a integer" do
      env = %Env{options: [type: :integer]}

      assert {:ok, 42} = Type.cast(env, "42")
    end

    test "casts a negative integer" do
      env = %Env{options: [type: :neg_integer]}

      assert {:ok, -1} = Type.cast(env, "-1")
    end

    test "casts a non negative integer" do
      env = %Env{options: [type: :non_neg_integer]}

      assert {:ok, 0} = Type.cast(env, "0")
    end

    test "casts a positive integer" do
      env = %Env{options: [type: :pos_integer]}

      assert {:ok, 1} = Type.cast(env, "1")
    end

    test "casts a float" do
      env = %Env{options: [type: :float]}

      assert {:ok, 42.0} = Type.cast(env, "42.0")
    end

    test "casts a boolean" do
      env = %Env{options: [type: :boolean]}

      assert {:ok, true} = Type.cast(env, "TRUE")
      assert {:ok, false} = Type.cast(env, "FALSE")
    end

    test "casts a atom" do
      env = %Env{options: [type: :atom]}

      assert {:ok, :foo} = Type.cast(env, "foo")
    end

    test "casts a module" do
      env = %Env{options: [type: :module]}

      assert {:ok, Skogsra.Type} = Type.cast(env, "Skogsra.Type")
    end

    test "casts an unsafe module" do
      env = %Env{options: [type: :unsafe_module]}

      assert {:ok, Foo} = Type.cast(env, "Foo")
    end

    test "does nothing to the value when it's of any type" do
      env = %Env{options: [type: :any]}

      assert {:ok, "Foo"} = Type.cast(env, "Foo")
    end

    test "casts a custom type" do
      defmodule CustomType do
        use Skogsra.Type

        def cast(value) when is_binary(value) do
          list =
            value
            |> String.split(~r/,/)
            |> Stream.map(&String.trim/1)
            |> Enum.map(&String.to_integer/1)

          {:ok, list}
        end

        def cast(_) do
          :error
        end
      end

      env = %Env{options: [type: CustomType]}

      assert {:ok, [1, 2, 3]} = Type.cast(env, "1, 2, 3")
    end
  end

  describe "cast_binary/1" do
    test "casts when is binary" do
      assert {:ok, "foo"} = Type.cast_binary("foo")
    end

    test "casts when it can be converted to binary" do
      assert {:ok, <<42>>} = Type.cast_binary([42])
    end

    test "errors when it cannot be converted to string" do
      assert :error = Type.cast_binary(%{foo: 42})
    end
  end

  describe "cast_integer/1" do
    test "casts when is integer" do
      assert {:ok, 42} = Type.cast_integer(42)
    end

    test "casts when it's a binary that can be converted to integer" do
      assert {:ok, 42} = Type.cast_integer("42")
    end

    test "errors when it's a binary that cannot be converted to integer" do
      assert :error = Type.cast_integer("42.0")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_integer(42.0)
    end
  end

  describe "cast_neg_integer/1" do
    test "casts when is negative integer" do
      assert {:ok, -1} = Type.cast_neg_integer(-1)
    end

    test "casts when it's a binary that can be converted to negative integer" do
      assert {:ok, -1} = Type.cast_neg_integer("-1")
    end

    test "errors when it's a binary that cannot be converted to negative integer" do
      assert :error = Type.cast_neg_integer("0")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_neg_integer(-1.0)
    end
  end

  describe "cast_non_neg_integer/1" do
    test "casts when is non negative integer" do
      assert {:ok, 0} = Type.cast_non_neg_integer(0)
    end

    test "casts when it's a binary that can be converted to non negative integer" do
      assert {:ok, 0} = Type.cast_non_neg_integer("0")
    end

    test "errors when it's a binary that cannot be converted to non negative integer" do
      assert :error = Type.cast_non_neg_integer("-1")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_non_neg_integer(0.0)
    end
  end

  describe "cast_pos_integer/1" do
    test "casts when is positive integer" do
      assert {:ok, 1} = Type.cast_pos_integer(1)
    end

    test "casts when it's a binary that can be converted to positive integer" do
      assert {:ok, 1} = Type.cast_pos_integer("1")
    end

    test "errors when it's a binary that cannot be converted to positive integer" do
      assert :error = Type.cast_pos_integer("0")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_pos_integer(1.0)
    end
  end

  describe "cast_float/1" do
    test "casts when is float" do
      assert {:ok, 42.0} = Type.cast_float(42.0)
    end

    test "casts when it's a binary that can be converted to float" do
      assert {:ok, 42.0} = Type.cast_float("42.0")
    end

    test "errors when it's a binary that cannot be converted to float" do
      assert :error = Type.cast_float("42.foo")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_float(42)
    end
  end

  describe "cast_boolean/1" do
    test "casts when is boolean" do
      assert {:ok, true} = Type.cast_boolean(true)
    end

    test "casts when it's a valid boolean binary" do
      assert {:ok, true} = Type.cast_boolean("TRUE")
      assert {:ok, false} = Type.cast_boolean("FALSE")
    end

    test "errors when it's not a valid boolean binary" do
      assert :error = Type.cast_float("VERDAD")
    end

    test "errors when it's other type" do
      assert :error = Type.cast_float(1)
    end
  end

  describe "cast_atom/1" do
    test "casts when is atom" do
      assert {:ok, :foo} = Type.cast_atom(:foo)
    end

    test "cast when is a binary for an existing atom" do
      assert {:ok, :foo} = Type.cast_atom("foo")
    end

    test "errors when is a binary for a non existing atom" do
      assert :error = Type.cast_atom("FOO")
    end

    test "errors when is not binary or atom" do
      assert :error = Type.cast_atom(42)
    end
  end

  describe "cast_module/1" do
    test "casts when is module" do
      assert {:ok, Skogsra.Type} = Type.cast_module(Skogsra.Type)
    end

    test "errors when is not an existing module" do
      assert :error = Type.cast_module(Foo)
    end

    test "casts when the string is an existing module" do
      assert {:ok, Skogsra.Type} = Type.cast_module("Skogsra.Type")
    end

    test "errors when the string ins not an existing module" do
      assert :error = Type.cast_module("Foo")
    end

    test "errors when is not an atom or a binary" do
      assert :error = Type.cast_module(42)
    end
  end

  describe "cast_unsafe_module/1" do
    test "casts when is module" do
      assert {:ok, Skogsra.Type} = Type.cast_unsafe_module(Skogsra.Type)
    end

    test "casts when is a binary that can be a module" do
      assert {:ok, Skogsra.Type} = Type.cast_unsafe_module("Skogsra.Type")
      assert {:ok, Foo} = Type.cast_unsafe_module("Foo")
    end

    test "errors when is not an atom or a binary" do
      assert :error = Type.cast_unsafe_module(42)
    end
  end
end
