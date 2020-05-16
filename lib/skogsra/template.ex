defmodule Skogsra.Template do
  @moduledoc """
  This module defines several templates for OS environment variable definitions.
  """
  alias Skogsra.Docs
  alias Skogsra.Env

  @types [:elixir, :unix, :windows]

  @typedoc """
  Template type.
  """
  @type type :: :elixir | :unix | :windows

  @doc """
  Template internal structure.
  """
  defstruct [:docs, :env, :type]

  @typedoc """
  A template struct.
  """
  @type t :: %__MODULE__{
          docs: docs :: Docs.docs(),
          env: env :: Env.t(),
          type: type :: type
        }

  ############
  # Public API

  @doc """
  Builds a template struct from a map.
  """
  @spec new(map()) :: t()
  def new(%{type: type} = map) when type in @types do
    struct(__MODULE__, map)
  end

  @doc """
  Generates a template.
  """
  @spec generate([t()], Path.t()) :: :ok | {:error, File.posix()}
  def generate(templates, filename)

  def generate(templates, filename) when is_list(templates) do
    File.write(filename, generate(templates))
  end

  #########
  # Helpers

  @doc false
  @spec generate([t()]) :: binary()
  def generate(templates) when is_list(templates) do
    templates
    |> Stream.map(&generate_content/1)
    |> Enum.join()
  end

  # Generates content for a variable.
  @spec generate_content(t()) :: binary()
  defp generate_content(%__MODULE__{} = template) do
    "#{generate_docs(template)}#{generate_variable(template)}"
  end

  # Generates a veriable.
  @spec generate_variable(t()) :: binary()
  defp generate_variable(%__MODULE__{type: :elixir, env: env}) do
    ~s(#{Env.os_env(env)}="#{Env.default(env)}"\n\n)
  end

  defp generate_variable(%__MODULE__{type: :unix, env: env}) do
    ~s(export #{Env.os_env(env)}='#{Env.default(env)}'\n\n)
  end

  defp generate_variable(%__MODULE__{type: :windows, env: env}) do
    ~s(SET #{Env.os_env(env)}="#{Env.default(env)}"\r\n\r\n)
  end

  # Generates documentation.
  @spec generate_docs(t()) :: binary()
  defp generate_docs(template)

  defp generate_docs(%__MODULE__{type: :windows, docs: false, env: env}) do
    ":: TYPE #{Env.type(env)}\r\n"
  end

  defp generate_docs(%__MODULE__{docs: false, env: env}) do
    "# TYPE #{Env.type(env)}\n"
  end

  defp generate_docs(%__MODULE__{type: :windows, docs: docs, env: env}) do
    ":: DOCS\r\n#{comment_docs(:windows, docs)}\r\n:: TYPE #{Env.type(env)}\r\n"
  end

  defp generate_docs(%__MODULE__{docs: docs, env: env}) do
    "# DOCS\n#{comment_docs(:unix, docs)}\n# TYPE #{Env.type(env)}\n"
  end

  # Generates docs for the specific platform.
  @spec comment_docs(type(), binary()) :: binary()
  defp comment_docs(type, docs)

  defp comment_docs(:windows, docs) do
    docs
    |> String.split(~r/(\r\n|\n)/, trim: true)
    |> Enum.map(&":: #{&1}")
    |> Enum.intersperse("\r\n")
    |> Enum.join("")
  end

  defp comment_docs(_, docs) do
    docs
    |> String.split(~r/(\r\n|\n)/, trim: true)
    |> Enum.map(&"# #{&1}")
    |> Enum.intersperse("\n")
    |> Enum.join("")
  end
end
