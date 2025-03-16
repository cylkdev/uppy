ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = Application.ensure_all_started(:oban)

Uppy.Support.Repo.start_link()
Uppy.start_link()
Uppy.Support.StorageSandbox.start_link()
