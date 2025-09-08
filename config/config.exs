import Config

config :uppy, :ecto_repos, [Uppy.Support.Repo]

if Mix.env() === :test do
  config :uppy, :sql_sandbox, true

  config :uppy, Uppy.Support.Repo,
    username: "postgres",
    database: "uppy_test",
    password: "password",
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
    password: "password",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end

config :ecto_shorts,
  repo: Uppy.Support.Repo,
  error_module: EctoShorts.Actions.Error
