defmodule Logster.Mixfile do
  use Mix.Project

  def project do
    [app: :logster,
     version: "0.4.3",
     name: "Logster",
     description: "Easily parsable single-line plain text and JSON logger for Plug and Phoenix applications",
     package: package(),
     source_url: "https://github.com/navinpeiris/logster",
     homepage_url: "https://github.com/navinpeiris/logster",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: [extras: ["README.md"]]]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:plug, "~> 1.0"},
     {:poison, "~> 1.5 or ~> 2.0 or ~> 3.0"},

     {:earmark, "~> 1.0", only: :dev},
     {:ex_doc, "~> 0.14", only: :dev},

     {:mix_test_watch, "~> 0.2", only: :dev},
     {:ex_unit_notifier, "~> 0.1", only: :test}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Navin Peiris"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/navinpeiris/logster"}]
  end
end
