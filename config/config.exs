import Config

config :uppy,
  error_adapter: ErrorMessage,
  json_adapter: Jason,
  db_action_adapter: Uppy.DBActions.SimpleRepo,
  http_adapter: Uppy.HTTP.Finch,
  scheduler_adapter: Uppy.Schedulers.ObanScheduler,
  storage_adapter: Uppy.Storages.S3

if Mix.env() === :test do
  config :uppy,
    scheduler: [
      name: Uppy.Schedulers.ObanScheduler,
      notifier: Oban.Notifiers.PG,
      repo: Uppy.Support.Repo,
      queues: false,
      testing: :manual
    ]
else
  config :uppy,
    scheduler: [
      name: Uppy.Schedulers.ObanScheduler,
      notifier: Oban.Notifiers.PG,
      repo: Uppy.Support.Repo,
      queues: [
        move_to_destination: 5,
        abort_expired_multipart_upload: 5,
        abort_expired_upload: 5
      ]
    ]
end

config :uppy, ecto_repos: [Uppy.Support.Repo]

if Mix.env() === :test do
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
else
  config :uppy, Uppy.Support.Repo,
    username: "postgres",
    database: "uppy",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end
