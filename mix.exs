defmodule Logster.Mixfile do
  use Mix.Project

  def project do
    [
      app: :logster,
      version: "1.0.2",
      name: "Logster",
      description:
        "Easily parsable single-line plain text and JSON logger for Plug and Phoenix applications",
      package: package(),
      source_url: "https://github.com/navinpeiris/logster",
      homepage_url: "https://github.com/navinpeiris/logster",
      elixir: "~> 1.2",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: [extras: ["README.md"]],
      preferred_cli_env: [ci: :test]
    ]
  end

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
      {:ex_unit_notifier, "~> 0.1", only: :test}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Navin Peiris"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/navinpeiris/logster"}
    ]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors --force",
        "format --check-formatted",
        "test --raise",
        "credo"
      ]
    ]
  end
end
