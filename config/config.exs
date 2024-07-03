import Config

if Mix.env() in [:dev, :test] do
  config :uppy, ecto_repos: [Uppy.Support.Repo]
end

if System.get_env("CI") in [true, "true"] do
  import_config "release.exs"
end

if is_nil(System.get_env("CI")) and
     "config.secret.exs" |> Path.expand(__DIR__) |> File.exists?() do
  import_config "config.secret.exs"
end
