import Config

config :uppy, Uppy.Schedulers.ObanScheduler.Router,
  instances: %{
    abort_expired_multipart_upload: Uppy.Schedulers.ObanScheduler.Instance,
    abort_expired_upload: Uppy.Schedulers.ObanScheduler.Instance,
    move_to_destination: Uppy.Schedulers.ObanScheduler.Instance
  },
  workers: %{
    abort_expired_multipart_upload: Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredMultipartUploadWorker,
    abort_expired_upload: Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredUploadWorker,
    move_to_destination: Uppy.Schedulers.ObanScheduler.Workers.MoveToDestinationWorker
  }

if Mix.env() === :test do
  config :uppy, Uppy.Storages.S3,
    scheme: "http://",
    host: "s3.localhost.localstack.cloud",
    port: 4566
else
  config :uppy, Uppy.Storages.S3,
    access_key_id: ["<UPPY_S3_ACCESS_KEY_ID>"],
    secret_access_key: ["<UPPY_S3_SECRET_ACCESS_KEY>"]
end

config :uppy,
  error_adapter: ErrorMessage,
  json_adapter: Jason,
  db_action_adapter: Uppy.DBActions.SimpleRepo,
  http_adapter: Uppy.HTTP.Finch,
  scheduler_adapter: Uppy.Schedulers.ObanScheduler,
  storage_adapter: Uppy.Storages.S3

if Mix.env() === :test do
  config :uppy, Oban,
    repo: Uppy.Support.Repo,
    notifier: Oban.Notifiers.PG,
    queues: [],
    testing: :manual
else
  config :uppy, Oban,
    notifier: Oban.Notifiers.PG,
    queues: [
      move_to_destination: 5,
      abort_expired_multipart_upload: 5,
      abort_expired_upload: 5
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
