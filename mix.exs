defmodule Logster.MixProject do
  use Mix.Project

  @version "2.0.0-rc.3"
  @source_url "https://github.com/navinpeiris/logster"

  def project do
    [
      app: :logster,
      version: @version,
      name: "Logster",
      description:
        "Easily parsable single-line plain text and JSON logger for Plug and Phoenix applications",
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      test_coverage: [
        summary: [threshold: 100]
      ],
      preferred_cli_env: [ci: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:jason, "~> 1.1"},
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 1.2", only: :test}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Navin Peiris"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "MIGRATION_GUIDE.md"
      ]
    ]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors --force",
        "format --check-formatted",
        "test --cover --raise",
        "credo"
      ]
    ]
  end
end
