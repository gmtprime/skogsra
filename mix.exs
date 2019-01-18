defmodule Skogsra.Mixfile do
  use Mix.Project

  @version "1.0.1"

  def project do
    [
      app: :skogsra,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
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
      {:ex_doc, "~> 0.18.0", only: :dev, runtime: false},
      {:credo, "~> 0.9", only: :dev}
    ]
  end

  defp docs do
    [
      source_url: "https://github.com/gmtprime/skogsra",
      source_ref: "v#{@version}",
      main: Skogsra
    ]
  end

  defp description do
    """
    Skogsra is a library to manage OS environment variables and application
    configuration options with ease.
    """
  end

  defp package do
    [
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/gmtprime/skogsra"}
    ]
  end
end
