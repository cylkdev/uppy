defmodule Uppy.MixProject do
  use Mix.Project

  @source_url "https://github.com/cylkdev/uppy"
  @version "0.1.0"

  def project do
    [
      app: :uppy,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() === :prod,
      deps: deps(),
      description: "Declarative comparisons and changes",
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
      {:ex_doc, "~> 0.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.1", only: :test, runtime: false},
      {:credo, "~> 1.0", only: :test, runtime: false},
      {:dialyxir, "~> 1.0", only: :test, runtime: false},
      {:cloud_cache, git: "https://github.com/cylkdev/cloud_cache.git"},
      {:ex_aws, "~> 2.0", optional: true},
      {:ex_aws_s3, "~> 2.0", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:sweet_xml, ">= 0.0.0", optional: true},
      {:timex, "~> 3.0", optional: true},
      {:req, "~> 0.5", optional: true},
      {:ecto, "~> 3.0", optional: true},
      {:ecto_sql, "~> 3.0", optional: true},
      {:postgrex, ">= 0.0.0", optional: true},
      {:error_message, ">= 0.0.0", optional: true},
      {:sandbox_registry, ">= 0.0.0", only: :test, runtime: false}
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
end
