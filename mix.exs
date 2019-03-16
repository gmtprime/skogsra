defmodule Skogsra.Mixfile do
  use Mix.Project

  @version "1.1.1"

  def project do
    [
      app: :skogsra,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      name: "Skogsrå",
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Skogsra.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19.3", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: :dev}
    ]
  end

  #########
  # Package

  defp description do
    """
    Skogsra is a library to manage OS environment variables and application
    configuration options with ease.
    """
  end

  defp package do
    [
      description: description(),
      files: ["lib", "mix.exs", "README.md", ".formatter.exs"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/gmtprime/skogsra"}
    ]
  end

  defp docs do
    [
      source_url: "https://github.com/gmtprime/skogsra",
      source_ref: "v#{@version}",
      main: Skogsra
    ]
  end
end
