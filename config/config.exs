import Config

config :uppy,
  db_action_adapter: Uppy.CommonRepoAction,
  error_adapter: ErrorMessage,
  http_adapter: Uppy.HTTP.Finch,
  json_adapter: Jason,
  pipeline_module: nil,
  enable_scheduler: true,
  scheduler_adapter: Uppy.Schedulers.ObanScheduler,
  storage_adapter: Uppy.Storages.S3,
  oban_name: :uppy_oban,
  repo: Uppy.Repo

config :uppy, Oban,
  name: :uppy_oban,
  notifier: Oban.Notifiers.PG,
  repo: Uppy.Repo,
  queues: [
    abort_expired_multipart_upload: 5,
    abort_expired_upload: 5,
    move_to_destination: 5
  ]

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
else
  config :uppy, Uppy.Repo,
    username: "postgres",
    database: "uppy",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end
