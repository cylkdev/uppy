import Config

config :uppy, :repo, Uppy.Repo

config :ex_aws,
  region: "us-west-1",
  access_key_id: ["<REQUIS_AWS_ACCESS_KEY_ID>"],
  secret_access_key: ["<REQUIS_AWS_SECRET_ACCESS_KEY>"]

config :ecto_shorts, :repo, Uppy.Repo

config :cloud_cache, caches: [CloudCache.Adapters.S3]

cond do
  Mix.env() === :test ->
    config :cloud_cache, CloudCache.Adapters.S3,
      sandbox_enabled: true,
      localstack: false

  Mix.env() === :dev ->
    config :cloud_cache, CloudCache.Adapters.S3,
      sandbox_enabled: false,
      localstack: true,
      profile: "localstack"

  true ->
    config :cloud_cache, CloudCache.Adapters.S3,
      sandbox_enabled: false,
      localstack: false
end

config :uppy, :ecto_repos, [Uppy.Repo]

if Mix.env() === :test do
  config :uppy, :sql_sandbox, true

  config :uppy, Uppy.Repo,
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
  config :uppy, Uppy.Repo,
    username: "postgres",
    database: "uppy",
    password: "password",
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    log: :debug,
    pool_size: 10
end
