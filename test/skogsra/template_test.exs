defmodule Skogsra.TemplateTest do
  use ExUnit.Case, async: true

  alias Skogsra.Env
  alias Skogsra.Template

  setup do
    env = Env.new(nil, :myapp, :port, default: 80)

    {:ok, env: env}
  end

  describe "new/1" do
    test "generates a template for Elixir releases", %{env: env} do
      docs = "Port"

      params = %{
        docs: docs,
        env: env,
        type: :elixir
      }

      assert %Template{docs: ^docs, env: ^env, type: :elixir} =
               Template.new(params)
    end

    test "generates a template for Unix", %{env: env} do
      docs = "Port"

      params = %{
        docs: docs,
        env: env,
        type: :unix
      }

      assert %Template{docs: ^docs, env: ^env, type: :unix} =
               Template.new(params)
    end

    test "generates a template for Windows", %{env: env} do
      docs = "Port"

      params = %{
        docs: docs,
        env: env,
        type: :windows
      }

      assert %Template{docs: ^docs, env: ^env, type: :windows} =
               Template.new(params)
    end
  end

  describe "generate/1" do
    test "when docs are not present, generates release vars without them",
         %{env: env} do
      template = Template.new(%{docs: false, env: env, type: :elixir})
      expected = "# TYPE integer\nMYAPP_PORT=\"80\"\n\n"

      assert ^expected = Template.generate([template])
    end

    test "when docs are not present, generates unix vars without them",
         %{env: env} do
      template = Template.new(%{docs: false, env: env, type: :unix})
      expected = "# TYPE integer\nexport MYAPP_PORT='80'\n\n"

      assert ^expected = Template.generate([template])
    end

    test "when docs are not present, generates windows vars without them",
         %{env: env} do
      template = Template.new(%{docs: false, env: env, type: :windows})
      expected = ":: TYPE integer\r\nSET MYAPP_PORT=\"80\"\r\n\r\n"

      assert ^expected = Template.generate([template])
    end

    test "when docs are present, generates release vars with them",
         %{env: env} do
      template = Template.new(%{docs: "Port", env: env, type: :elixir})
      expected = "# DOCS Port\n# TYPE integer\nMYAPP_PORT=\"80\"\n\n"

      assert ^expected = Template.generate([template])
    end

    test "when docs are present, generates unix vars with them",
         %{env: env} do
      template = Template.new(%{docs: "Port", env: env, type: :unix})
      expected = "# DOCS Port\n# TYPE integer\nexport MYAPP_PORT='80'\n\n"

      assert ^expected = Template.generate([template])
    end

    test "when docs are present, generates windows vars with them",
         %{env: env} do
      template = Template.new(%{docs: "Port", env: env, type: :windows})

      expected =
        ":: DOCS Port\r\n:: TYPE integer\r\nSET MYAPP_PORT=\"80\"\r\n\r\n"

      assert ^expected = Template.generate([template])
    end
  end
end
