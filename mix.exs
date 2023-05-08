defmodule Skogsra.Mixfile do
  use Mix.Project

  @version "2.4.1"
  @name "Skogsrå"
  @description "Manages OS environment variables and application configuration options with ease"
  @app :skogsra
  @root "https://github.com/gmtprime/skogsra"

  def project do
    [
      name: @name,
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  #############
  # Application

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.3", optional: true},
      {:yamerl, "~> 0.10", optional: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/#{@app}.plt"},
      plt_add_apps: [:yamerl, :jason]
    ]
  end

  #########
  # Package

  defp package do
    [
      description: @description,
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", ".formatter.exs"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@root}/blob/master/CHANGELOG.md",
        "Github" => @root,
        "Sponsor" => "https://github.com/sponsors/alexdesousa"
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
