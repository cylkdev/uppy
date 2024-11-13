import Config

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
end
