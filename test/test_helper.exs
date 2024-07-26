ExUnit.start()

Code.put_compiler_option(:warnings_as_errors, true)

{:ok, _} = :application.ensure_all_started([
  :ecto,
  :hackney,
  :oban,
  :postgrex
])

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

{:ok, _} = Uppy.Adapters.HTTP.Finch.start_link()
