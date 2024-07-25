defmodule Uppy.MixProject do
  use Mix.Project

  def project do
    [
      app: :uppy,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() === :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        coverage: :test,
        dialyzer: :test,
        "coveralls.lcov": :test,
        "coveralls.json": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        list_unused_filters: true,
        plt_local_path: ".check/local_plt",
        plt_core_path: ".check/core_plt"
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
      {:ecto, "~> 3.11"},
      {:postgrex, ">= 0.0.0", optional: true},
      {:ecto_sql, "~> 3.11", optional: true},

      # required for Uppy.Error
      {:error_message, "~> 0.3.0", optional: true},

      # required for Uppy.Adapters.EctoShortsAction
      {:ecto_shorts, path: "../ecto_shorts", optional: true},

      # required for Uppy.Pipelines.Phases.Thumbor
      {:thumbor, git: "https://github.com/RequisDev/thumbor.git", branch: "main", optional: true},

      # required for Uppy.Adapters.Scheduler.Oban
      {:oban, "~> 2.17", optional: true},

      # required for Uppy.Adapters.Scheduler.Quantum
      {:quantum, "~> 3.5", optional: true},

      # required for Uppy.Adapters.Storage.S3
      {:ex_aws, "~> 2.1", optional: true},
      {:ex_aws_s3, "~> 2.0", optional: true},
      {:hackney, "~> 1.9", optional: true},
      {:sweet_xml, "~> 0.6", optional: true},

      # required for Uppy.Adapters.HTTP.Finch
      {:finch, "~> 0.18.0", optional: true},

      # test dependencies
      {:sandbox_registry, "~> 0.1", optional: true},
      {:factory_ex, "~> 0.3.4", only: [:dev, :test], optional: true},
      {:faker, "~> 0.18", only: [:dev, :test], optional: true},
      {:excoveralls, "~> 0.14.6", only: :test, runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  if Mix.env() in [:dev, :test] do
    defp aliases do
      [
        setup: ["deps.get", "ecto.setup"],
        "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
        "ecto.reset": ["ecto.drop", "ecto.setup"],
        "ecto.seed": ["run priv/repo/seeds.exs"]
      ]
    end
  else
    defp aliases do
      []
    end
  end
end
