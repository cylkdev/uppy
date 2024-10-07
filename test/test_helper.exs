ExUnit.start()

if System.get_env("CI") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

:ok = FactoryEx.SchemaCounter.start()

for app <- [:ecto, :oban, :postgrex] do
  Application.ensure_all_started(app)
end

{:ok, _} = Uppy.Repo.start_link()

{:ok, _} =
  Oban.start_link(
    name: Uppy.Oban,
    repo: Uppy.Repo,
    queues: [
      post_processing_pipeline: 20,
      abort_upload: 10,
      object_garbage_collection: 5
    ],
    testing: :manual
  )

{:ok, _} = Uppy.Support.StorageSandbox.start_link()

{:ok, _} = Uppy.HTTP.Finch.start_link()
