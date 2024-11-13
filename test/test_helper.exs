ExUnit.start()

if System.get_env("CI") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

for app <- [:oban, :postgrex] do
  Application.ensure_all_started(app)
end

Uppy.Repo.start_link()

Uppy.StorageSandbox.start_link()
Uppy.HTTP.Finch.start_link()

Application.put_all_env([
  ecto_shorts: [
    repo: Uppy.Repo,
    error_module: EctoShorts.Actions.Error
  ],
  ex_aws: [
    s3: [
      scheme: "http://",
      host: "s3.localhost.localstack.cloud",
      port: 4566,
      region: "us-west-1",
      access_key_id: ["<UPPY_ACCESS_KEY_ID>"],
      secret_access_key: ["<UPPY_SECRET_ACCESS_KEY>"]
    ]
  ]
])
