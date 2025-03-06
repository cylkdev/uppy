ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = Application.ensure_all_started(:oban)

Uppy.Support.Repo.start_link()

Uppy.start_link(
  scheduler: [
    options: [repo: Uppy.Support.Repo]
  ]
)

Uppy.Support.StorageSandbox.start_link()

Application.put_env(:ex_aws, :s3,
  scheme: "http://",
  host: "s3.localhost.localstack.cloud",
  port: 4566,
  region: "us-west-1",
  access_key_id: ["UPPY_ACCESS_KEY_ID"],
  secret_access_key: ["UPPY_SECRET_ACCESS_KEY"]
)
