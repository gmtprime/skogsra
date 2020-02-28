defmodule Skogsra.Mixfile do
  use Mix.Project

  @version "2.2.0"
  @root "https://github.com/gmtprime/skogsra"

  def project do
    [
      app: :skogsra,
      version: @version,
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      name: "Skogsrå",
      dialyzer: dialyzer(),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  #############
  # Application

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:yamerl, "~> 0.7", optional: true},
      {:jason, "~> 1.1", optional: true},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.2", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false}
    ]
  end

  defp dialyzer do
    [plt_add_apps: [:yamerl, :jason]]
  end

  #########
  # Package

  defp description do
    """
    Manages OS environment variables and application configuration options with
    ease.
    """
  end

  defp package do
    [
      description: description(),
      files: ["lib", "mix.exs", "README.md", ".formatter.exs"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@root}/blob/master/CHANGELOG.md",
        "Github" => @root
      }
    ]
  end

  ###############
  # Documentation

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      source_url: @root,
      source_ref: "v#{@version}",
      groups_for_modules: [
        Skogsra: [
          Skogsra,
          Skogsra.Settings
        ],
        "Library Core": [
          Skogsra.Env,
          Skogsra.Core
        ],
        Generalizations: [
          Skogsra.Cache,
          Skogsra.Type
        ],
        "Variable Bindings": [
          Skogsra.Binding,
          Skogsra.App,
          Skogsra.Sys
        ],
        "Documentation Generation": [
          Skogsra.Docs,
          Skogsra.Spec
        ],
        "OS Environment Template": [
          Skogsra.Template
        ],
        "Config Providers": [
          Skogsra.Provider.Yaml,
          Skogsra.Provider.Json
        ]
      ]
    ]
  end
end
