defmodule Uppy.MixProject do
  use Mix.Project

  @source_url "https://github.com/RequisDev/uppy"
  @version "0.1.0"

  def project do
    [
      app: :uppy,
      version: @version,
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
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
        plt_add_apps: [
          :ecto,
          :ecto_sql,
          :ecto_shorts,
          :ex_aws,
          :ex_aws_s3,
          :ex_image_info,
          :ex_unit,
          :faker,
          :factory_ex,
          :finch,
          :file_type,
          :decimal,
          :mix,
          :nimble_options,
          :oban,
          :sandbox_registry
        ],
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
      {:ex_doc, "~> 0.28.4", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.3", only: :test, runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", runtime: false},

      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11", optional: true},
      {:postgrex, ">= 0.0.0", optional: true},
      {:tzdata, "~> 1.1"},

      {:ecto_shorts, "~> 2.4"},
      {:error_message, "~> 0.3.0", optional: true},

      {:finch, "~> 0.18.0", optional: true},
      {:thumbor, git: "https://github.com/RequisDev/thumbor.git", branch: "main", optional: true},

      {:ex_aws, "~> 2.1", optional: true},
      {:ex_aws_s3, "~> 2.0", optional: true},
      {:sweet_xml, "~> 0.6", optional: true},

      {:oban, "~> 2.17", optional: true},
      {:quantum, "~> 3.5", optional: true},

      {:ex_image_info, "~> 0.2.4", optional: true},
      {:file_type, "~> 0.1.0", optional: true},

      {:sandbox_registry, "~> 0.1", optional: true},
      {:factory_ex, "~> 0.3.4", only: [:dev, :test], optional: true},
      {:faker, "~> 0.18", only: [:dev, :test], optional: true}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Kurt Hogarth"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cylkdev/substitute_x"},
      files: ~w(mix.exs README.md CHANGELOG.md lib)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/cylkdev/substitute_x",
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
