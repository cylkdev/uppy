import Config

if Mix.env() === :test do
  config :uppy, ecto_repos: [Uppy.Support.Repo]
  config :uppy, :sql_sandbox, true

  config :uppy, Uppy.Support.Repo,
    username: "postgres",
    database: "uppy_test",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    stacktrace: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :ecto_shorts,
    repo: Uppy.Support.Repo,
    error_module: EctoShorts.Actions.Error

  config :uppy, Oban,
    name: Uppy.Oban,
    repo: Uppy.Support.Repo,
    queues: [
      post_processing_pipeline: 50,
      abort_upload: 10,
      object_garbage_collection: 5
    ],
    testing: :manual
end

if System.get_env("CI") in [true, "true"] do
  import_config "release.exs"
end

if is_nil(System.get_env("CI")) and File.exists?(Path.expand("config.secret.exs", __DIR__)) do
  import_config "config.secret.exs"
end
