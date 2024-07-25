import Config

config :uppy, ecto_repos: [Uppy.Repo]

if Mix.env() === :test do
  config :ecto_shorts,
    repo: Uppy.Repo,
    error_module: EctoShorts.Actions.Error

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
    database: "uppy_test",
    hostname: "localhost",
    pool_size: 10,
    show_sensitive_data_on_connection_error: true,
    stacktrace: true
end

if System.get_env("CI") in [true, "true"] do
  import_config "release.exs"
end

if is_nil(System.get_env("CI")) and File.exists?(Path.expand("config.secret.exs", __DIR__)) do
  import_config "config.secret.exs"
end
