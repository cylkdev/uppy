defmodule Uppy.MixProject do
  use Mix.Project

  @source_url "https://github.com/cylkdev/uppy"
  @version "0.1.0"

  def project do
    [
      app: :uppy,
      version: @version,
      description: "Declarative comparisons and changes",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() === :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        dialyzer: :test,
        coveralls: :test,
        "coveralls.lcov": :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test
      ],
      dialyzer: [
        list_unused_filters: true,
        plt_local_path: "dialyzer",
        plt_core_path: "dialyzer",
        flags: [:unmatched_returns]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # linting/documentation dependencies
      {:ex_doc, "~> 0.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.1", only: :test, runtime: false},
      {:credo, "~> 1.0", only: :test, runtime: false},
      {:dialyxir, "~> 1.0", only: :test, runtime: false},

      # ex_aws dependencies
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:sweet_xml, ">= 0.0.0"},
      {:configparser_ex, "~> 5.0"},

      # ecto dependencies
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},

      # testing
      {:sandbox_registry, ">= 0.0.0"},

      # app dependencies
      {:proper_case, "~> 1.0"},
      {:timex, "~> 3.0"},
      {:req, "~> 0.5"},
      {:error_message, ">= 0.0.0"},
      {:ecto_shorts,
       git: "https://github.com/cylkdev/ecto_shorts.git", branch: "cylkdev-ecto-shorts-2.5.0"},
      {:cloud_cache, git: "https://github.com/cylkdev/cloud_cache.git", branch: "main"},
      {:oban, "~> 2.15"},
      {:cue, git: "https://github.com/cylkdev/cue.git", branch: "main"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Kurt Hogarth"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cylkdev/uppy"},
      files: ~w(mix.exs README.md CHANGELOG.md lib)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/cylkdev/uppy",
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.txt": [title: "License"],
        "README.md": [title: "Readme"]
      ],
      source_url: @source_url,
      source_ref: @version,
      api_reference: false,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.seed": ["run priv/repo/seeds.exs"]
    ]
  end
end
