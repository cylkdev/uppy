ExUnit.start()

if System.get_env("CI") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

for app <- [:oban, :postgrex] do
  Application.ensure_all_started(app)
end

{:ok, _} = Uppy.Repo.start_link()
{:ok, _} = Uppy.Schedulers.ObanScheduler.start_link()

{:ok, _} = Uppy.StorageSandbox.start_link()
{:ok, _} = Uppy.HTTP.Finch.start_link()

Application.put_all_env([
  ecto_shorts: [
    repo: Uppy.Repo,
    error_module: EctoShorts.Actions.Error
  ]
])
