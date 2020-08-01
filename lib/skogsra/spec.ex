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
  defp get_spec_type(type, present?)

  defp get_spec_type(:binary, true), do: quote(do: binary())
  defp get_spec_type(:integer, true), do: quote(do: integer())
  defp get_spec_type(:neg_integer, true), do: quote(do: neg_integer())
  defp get_spec_type(:non_neg_integer, true), do: quote(do: non_neg_integer())
  defp get_spec_type(:pos_integer, true), do: quote(do: pos_integer())
  defp get_spec_type(:float, true), do: quote(do: float())
  defp get_spec_type(:boolean, true), do: quote(do: boolean())
  defp get_spec_type(:atom, true), do: quote(do: atom())
  defp get_spec_type(:module, true), do: quote(do: module())
  defp get_spec_type(:unsafe_module, true), do: quote(do: module())
  defp get_spec_type(:any, true), do: quote(do: any())

  defp get_spec_type({:__aliases__, _, _} = module, true) do
    quote do: unquote(module).t()
  end

  defp get_spec_type(other, false) do
    quote do: nil | unquote(get_spec_type(other, true))
  end

  defp get_spec_type(options) when is_list(options) do
    env = %Env{options: options}
    type = Env.type(env)
    present? = Env.required?(env) or not is_nil(Env.default(env))

    get_spec_type(type, present?)
  end
end
