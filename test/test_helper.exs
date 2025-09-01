ExUnit.start()

for app <- [:postgrex, :ecto, :oban] do
  {:ok, _} = Application.ensure_all_started(app)
end

Uppy.Support.Repo.start_link()
