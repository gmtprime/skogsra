defmodule Skogsra.Spec do
  @moduledoc """
  This module defines the spec generators.
  """
  alias Skogsra.Env

  @doc """
  Generates spec for a configuration function.
  """
  def gen_full_spec(function_name, options) do
    type = get_spec_type(options)

    quote do
      @spec unquote(function_name)() ::
              {:ok, unquote(type)} | {:error, binary()}
      @spec unquote(function_name)(Env.namespace()) ::
              {:ok, unquote(type)} | {:error, binary()}
    end
  end

  @doc """
  Generates spec for a bang function.
  """
  def gen_bang_spec(function_name, options) do
    type = get_spec_type(options)

    quote do
      @spec unquote(function_name)() ::
              unquote(type) | no_return()
      @spec unquote(function_name)(Env.namespace()) ::
              unquote(type) | no_return()
    end
  end

  @doc """
  Generates reload spec for a configuration function.
  """
  def gen_reload_spec(function_name, options) do
    gen_full_spec(function_name, options)
  end

  @doc """
  Generates put spec for a configuration function.
  """
  def gen_put_spec(function_name, options) do
    type = get_spec_type(options)

    quote do
      @spec unquote(function_name)(unquote(type)) ::
              :ok | {:error, binary()}
      @spec unquote(function_name)(unquote(type), Env.namespace()) ::
              :ok | {:error, binary()}
    end
  end

  #########
  # Helpers

  # Get the spec type given a configuration.
  defp get_spec_type(:binary), do: (quote do: binary())
  defp get_spec_type(:integer), do: (quote do: integer())
  defp get_spec_type(:float), do: (quote do: float())
  defp get_spec_type(:boolean), do: (quote do: boolean())
  defp get_spec_type(:atom), do: (quote do: atom())
  defp get_spec_type(:module), do: (quote do: module())
  defp get_spec_type(:unsafe_module), do: (quote do: module())
  defp get_spec_type(module) when is_atom(module), do: (quote do: unquote(module).t())
  defp get_spec_type(options) when is_list(options) do
    %Env{options: options}
    |> Env.type()
    |> get_spec_type()
  end
end
