defmodule Skogsra.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :skogsra,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.15", only: :dev},
     {:credo, "~> 0.7", only: :dev},
     {:inch_ex, "~> 0.5", only: [:dev, :docs]}]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/skogsra",
     source_ref: "v#{@version}",
     main: Skogsra]
  end

  defp description do
    """
    Skogsra is a library to manage OS environment variables and application
    configuration options with ease.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licences: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/skogsra"}]
  end
end
