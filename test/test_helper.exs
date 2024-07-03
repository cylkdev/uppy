ExUnit.start()

Code.put_compiler_option(:warnings_as_errors, true)

:application.ensure_all_started([
  :ecto,
  :hackney,
  :oban,
  :postgrex
])

{:ok, _} = Uppy.Support.Repo.start_link()
{:ok, _} = Oban.start_link(Uppy.Adapters.Scheduler.Oban.Config.get_env())

Uppy.Support.StorageSandbox.start_link()
