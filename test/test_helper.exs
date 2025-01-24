ExUnit.start()

{:ok, _} = :application.ensure_all_started(:postgrex)
{:ok, _} = :application.ensure_all_started(:ecto)
{:ok, _} = :application.ensure_all_started(:oban)

Uppy.Repo.start_link()

Oban.start_link(
  name: Uppy.Oban,
  repo: Uppy.Repo,
  queues: [
    abort_expired_multipart_upload: 5,
    abort_expired_upload: 5,
    post_processing: 5
  ]
)

Uppy.StorageSandbox.start_link()

Uppy.HTTP.Finch.start_link()

Application.put_env(:ex_aws, :s3,
  scheme: "http://",
  host: "s3.localhost.localstack.cloud",
  port: 4566,
  region: "us-west-1",
  access_key_id: ["<UPPY_ACCESS_KEY_ID>"],
  secret_access_key: ["<UPPY_SECRET_ACCESS_KEY>"]
)
