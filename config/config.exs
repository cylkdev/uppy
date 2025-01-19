import Config

config :uppy,
  db_action_adapter: EctoShorts.Actions,
  error_adapter: ErrorMessage,
  http_adapter: Uppy.HTTP.Finch,
  json_adapter: Jason,
  oban_name: Uppy.Oban,
  scheduler_adapter: Uppy.Schedulers.ObanScheduler,
  storage_adapter: Uppy.Storages.S3,
  pipeline_resolver: nil



config :uppy, ecto_repos: [Uppy.Repo]

if Mix.env() === :test do
  config :uppy, :sql_sandbox, true
  config :uppy, Uppy.Repo,
    username: "postgres",
    database: "uppy_test",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    stacktrace: true,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :uppy, Oban,
    name: Uppy.Oban,
    queues: [
      abort_expired_multipart_upload: 10,
      abort_expired_upload: 10,
      post_processing: 5
    ]
else
  config :uppy, Uppy.Repo,
    username: "postgres",
    database: "uppy",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end
