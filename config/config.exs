import Config

config :uppy,
  bucket: "your-bucket",
  error_adapter: ErrorMessage,
  json_adapter: Jason

# config :uppy,
#   db_action_adapter: Uppy.DBActions.SimpleRepo,
#   error_adapter: ErrorMessage,
#   http_adapter: Uppy.HTTP.Finch,
#   json_adapter: Jason,
#   pipeline_module: nil,
#   scheduler_enabled: true,
#   scheduler_adapter: Uppy.Uploader.Engines.ObanScheduler,
#   storage_adapter: Uppy.Storages.S3

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
