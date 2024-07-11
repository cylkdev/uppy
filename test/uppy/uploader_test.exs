defmodule Uppy.UploaderTest do
  use Uppy.Support.DataCase, async: true

  doctest Uppy.Uploader

  alias Uppy.{
    Support.Factory,
    Support.PG,
    Support.StorageSandbox,
    Uploader
  }

  @bucket "bucket"
  @resource_name "user-avatars"
  @filename "image.jpeg"

  @schema Uppy.Support.PG.Objects.UserAvatarObject
  @action_adapter Uppy.Adapters.Action
  @storage_adapter Uppy.Adapters.Storage.S3
  @permanent_scope_adapter Uppy.Adapters.PermanentScope
  @temporary_scope_adapter Uppy.Adapters.TemporaryScope

  defmodule MockUploader do
    use Uppy.Uploader,
      bucket: "bucket",
      resource_name: "user-avatars",
      queryable: Uppy.Support.PG.Objects.UserAvatarObject,
      pipeline: [
        Uppy.Pipeline.Phases.EctoHolderLoader,
        Uppy.Pipeline.Phases.PutObjectCopy
      ]
  end

  @e_tag "e_tag"
  @head_object_params %{
    content_length: 11,
    content_type: "text/plain",
    e_tag: @e_tag,
    last_modified: ~U[2023-08-18 10:53:21Z]
  }

  setup do
    company = FactoryEx.insert!(Factory.Accounts.Company)
    user = FactoryEx.insert!(Factory.Accounts.User, %{company_id: company.id})
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})

    user_avatar =
      FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

    %{
      company: company,
      user: user,
      user_profile: user_profile,
      user_avatar: user_avatar
    }
  end

  setup do
    StorageSandbox.set_presigned_url_responses([
      {@bucket,
       fn _http_method, object ->
         {:ok,
          %{
            url: "http://presigned.url/#{object}",
            expires_at: DateTime.add(DateTime.utc_now(), 60_000)
          }}
       end}
    ])
  end

  describe "&start_upload/5" do
    @tag oban_testing: "manual"
    test "creates presigned upload, database record and lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok,
                %{
                  unique_identifier: unique_identifier,
                  key: key,
                  presigned_upload: presigned_upload,
                  schema_data: schema_data,
                  job: _
                }} =
                 Uploader.start_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        # required parameters are not null
        assert unique_identifier
        assert key

        # the key has the temporary path prefix and the temporary object key adapter
        # recognizes it as being in a temporary path.
        assert "temp/" <> _ = key
        assert @temporary_scope_adapter.path?(key)

        # the presigned upload payload contains a valid key, url and expiration
        assert %{
                 url: presigned_upload_url,
                 expires_at: presigned_upload_expires_at
               } = presigned_upload

        assert String.contains?(presigned_upload_url, key)
        assert DateTime.compare(presigned_upload_expires_at, DateTime.utc_now()) === :gt

        # the expected fields are set on the schema data
        assert %PG.Objects.UserAvatarObject{} = schema_data
        assert schema_data.unique_identifier === unique_identifier
        assert schema_data.key === key
        assert schema_data.filename === @filename

        # sanity check the record exists
        assert {:ok, _} = PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # job is scheduled that deletes the record
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.UploadAborterWorker,
          args: %{
            event: "uppy.upload_aborter.abort_upload",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data.id
          },
          queue: :abort_uploads
        )

        assert {:ok,
                %{
                  job: garbage_collect_object_job,
                  schema_data: abort_upload_job_schema_data
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.UploadAborterWorker, %{
                   event: "uppy.upload_aborter.abort_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data.id
                 })

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: ^expected_job_key
                 }
               } = garbage_collect_object_job

        assert %PG.Objects.UserAvatarObject{} = abort_upload_job_schema_data

        # job should return the same record
        assert schema_data.id === abort_upload_job_schema_data.id

        # The record should not exists
        assert {:error, %{code: :not_found}} =
                 PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # after performing the job another job should be schedule that can
        # garbage collect the object if it was uploaded after expiration.
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          args: %{
            event: "uppy.garbage_collector.garbage_collect_object",
            uploader: "Uppy.UploaderTest.MockUploader",
            key: schema_data.key
          },
          queue: :garbage_collection
        )

        # storage head_object must return an ok response
        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        StorageSandbox.set_delete_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert :ok =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })
      end)
    end
  end

  describe "&abort_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        assert {:ok,
                %{
                  job: garbage_collect_object_job,
                  schema_data: abort_upload_schema_data
                }} = Uploader.abort_upload(MockUploader, %{id: schema_data.id}, [])

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   key: ^expected_job_key,
                   uploader: "Uppy.UploaderTest.MockUploader"
                 }
               } = garbage_collect_object_job

        assert abort_upload_schema_data.id === schema_data.id

        # The record should not exists
        assert {:error, %{code: :not_found}} =
                 PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # after performing the job another job should be schedule that can
        # garbage collect the object if it was uploaded after expiration.
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          args: %{
            event: "uppy.garbage_collector.garbage_collect_object",
            uploader: "Uppy.UploaderTest.MockUploader",
            key: schema_data.key
          },
          queue: :garbage_collection
        )

        # storage head_object must return an ok response
        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        StorageSandbox.set_delete_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert :ok =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })
      end)
    end
  end

  describe "&complete_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: schema_data_id,
                 unique_identifier: schema_data_unique_identifier,
                 key: schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: schema_data_user_avatar_id,
                 user_id: schema_data_user_id,
                 # the object metadata fields should be nil
                 e_tag: nil,
                 upload_id: nil,
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = schema_data

        assert schema_data_user_id === context.user.id
        assert schema_data_user_avatar_id === context.user_avatar.id
        assert schema_data_unique_identifier
        assert schema_data_key

        assert {:ok,
                %{
                  schema_data: complete_upload_schema_data,
                  metadata: complete_upload_metadata,
                  job: run_pipeline_job
                }} = Uploader.complete_upload(MockUploader, %{id: schema_data_id}, [])

        assert complete_upload_metadata === @head_object_params

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = run_pipeline_job

        # e_tag should be the only new value set on the completed upload record
        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: complete_upload_schema_data_id,
                 unique_identifier: complete_upload_schema_data_unique_identifier,
                 key: complete_upload_schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: complete_upload_schema_data_user_avatar_id,
                 user_id: complete_upload_schema_data_user_id,
                 # object metadata fields except e_tag should be nil
                 e_tag: complete_upload_schema_data_e_tag,
                 upload_id: nil,
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = complete_upload_schema_data

        assert is_binary(complete_upload_schema_data_e_tag)

        # these should be the starting values
        assert complete_upload_schema_data_id === schema_data_id

        assert complete_upload_schema_data_unique_identifier ===
                 schema_data_unique_identifier

        assert complete_upload_schema_data_key === schema_data_key

        assert complete_upload_schema_data_user_avatar_id ===
                 schema_data_user_avatar_id

        assert complete_upload_schema_data_user_id === context.user.id

        assert complete_upload_schema_data.id === schema_data_id

        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.PostProcessorWorker,
          args: %{
            event: "uppy.post_processor.run_pipeline",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data_id
          },
          queue: :post_processing
        )

        StorageSandbox.set_put_object_copy_responses([
          {
            @bucket,
            fn ->
              {:ok,
               %{
                 body: "body",
                 headers: [
                   {"x-amz-id-2", "amz_id"},
                   {"x-amz-request-id", "C6KG1R8WTNFSTX5F"},
                   {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
                   {"x-amz-server-side-encryption", "AES256"},
                   {"content-type", "application/xml"},
                   {"server", "AmazonS3"},
                   {"content-length", "224"}
                 ],
                 status_code: 200
               }}
            end
          }
        ])

        assert {:ok,
                %{
                  result:
                    %{
                      value: job_pipeline_schema_data,
                      context: %{
                        bucket: @bucket,
                        schema: @schema,
                        resource_name: @resource_name,
                        action_adapter: @action_adapter,
                        storage_adapter: @storage_adapter,
                        permanent_scope_adapter: @permanent_scope_adapter,
                        temporary_scope_adapter: @temporary_scope_adapter
                      },
                      private: job_pipeline_private
                    } = _input,
                  phases: [
                    Uppy.Pipeline.Phases.PutObjectCopy,
                    Uppy.Pipeline.Phases.EctoHolderLoader
                  ]
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.PostProcessorWorker, %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # pipeline result should match the input
        assert job_pipeline_schema_data.id === schema_data_id

        assert [
                 {
                   Elixir.Uppy.Pipeline.Phases.PutObjectCopy,
                   %{
                     basename: job_pipeline_private_basename,
                     metadata: @head_object_params,
                     schema_data:
                       %Uppy.Support.PG.Objects.UserAvatarObject{
                         e_tag: @e_tag,
                         upload_id: nil,
                         archived: false,
                         archived_at: nil,
                         inserted_at: _,
                         updated_at: _
                       } = job_pipeline_private_schema_data,
                     partition_id: job_pipeline_partition_id,
                     destination_object: job_pipeline_destination_object,
                     source_object: job_pipeline_source_object
                   }
                 }
               ] = job_pipeline_private

        assert job_pipeline_partition_id === context.user.company_id

        assert job_pipeline_private_schema_data.id === schema_data.id
        assert job_pipeline_private_schema_data.user_id === context.user.id
        assert job_pipeline_private_schema_data.user_avatar_id === context.user_avatar.id

        expected_permanent_object =
          Enum.join([
            "#{String.reverse("#{context.user.company_id}")}-user-avatars/",
            "#{schema_data.unique_identifier}-#{schema_data.filename}"
          ])

        assert job_pipeline_private_schema_data.key === expected_permanent_object
        assert job_pipeline_destination_object === expected_permanent_object
        assert job_pipeline_source_object === schema_data.key

        assert job_pipeline_private_basename ===
                 "#{schema_data.unique_identifier}-#{schema_data.filename}"

        assert job_pipeline_private_schema_data.content_length ===
                 @head_object_params.content_length

        assert job_pipeline_private_schema_data.content_type === @head_object_params.content_type

        assert job_pipeline_private_schema_data.last_modified ===
                 @head_object_params.last_modified
      end)
    end
  end

  describe "&start_multipart_upload/5" do
    @tag oban_testing: "manual"
    test "creates multipart upload, database record and lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        StorageSandbox.set_initiate_multipart_upload_responses([
          {@bucket,
           fn object ->
             {:ok,
              %{
                key: object,
                bucket: @bucket,
                upload_id: "upload_id"
              }}
           end}
        ])

        assert {:ok,
                %{
                  unique_identifier: unique_identifier,
                  key: key,
                  multipart_upload: %{
                    key: multipart_upload_key,
                    bucket: @bucket,
                    upload_id: "upload_id"
                  },
                  schema_data: schema_data
                }} =
                 Uploader.start_multipart_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        # required parameters are not null
        assert unique_identifier
        assert multipart_upload_key === key

        # the key has the temporary path prefix and the temporary object key adapter
        # recognizes it as being in a temporary path.
        assert "temp/" <> _ = key
        assert @temporary_scope_adapter.path?(key)

        # the expected fields are set on the schema data
        assert %PG.Objects.UserAvatarObject{} = schema_data
        assert schema_data.unique_identifier === unique_identifier
        assert schema_data.key === key
        assert schema_data.filename === @filename

        # sanity check the record exists
        assert {:ok, _} = PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # job is scheduled that deletes the record
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.UploadAborterWorker,
          args: %{
            event: "uppy.upload_aborter.abort_multipart_upload",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data.id
          },
          queue: :abort_uploads
        )

        StorageSandbox.set_abort_multipart_upload_responses([
          {@bucket,
           fn ->
             {:ok,
              %{
                body: "",
                headers: [
                  {"x-amz-id-2",
                   "LQXU1lr7kVEJe+MIP6t5vM0rLN3mDSdTkRI3Mw0EV7QZQsSy2dWkO6SEdwxH1ZnLMZ9TBEQjXZ4="},
                  {"x-amz-request-id", "S8HCXECRERKT8F8S"},
                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                  {"server", "AmazonS3"}
                ],
                status_code: 204
              }}
           end}
        ])

        assert {:ok,
                %{
                  job: garbage_collect_object_job,
                  schema_data: abort_upload_job_schema_data
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.UploadAborterWorker, %{
                   event: "uppy.upload_aborter.abort_multipart_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data.id
                 })

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: ^expected_job_key
                 }
               } = garbage_collect_object_job

        assert %PG.Objects.UserAvatarObject{} = abort_upload_job_schema_data

        # job should return the same record
        assert schema_data.id === abort_upload_job_schema_data.id

        # The record should not exists
        assert {:error, %{code: :not_found}} =
                 PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # after performing the job another job should be schedule that can
        # garbage collect the object if it was uploaded after expiration.
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          args: %{
            event: "uppy.garbage_collector.garbage_collect_object",
            uploader: "Uppy.UploaderTest.MockUploader",
            key: schema_data.key
          },
          queue: :garbage_collection
        )

        # storage head_object must return an ok response
        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        StorageSandbox.set_delete_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert :ok =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })
      end)
    end
  end

  describe "&abort_multipart_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        StorageSandbox.set_initiate_multipart_upload_responses([
          {@bucket,
           fn object ->
             {:ok,
              %{
                key: object,
                bucket: @bucket,
                upload_id: "upload_id"
              }}
           end}
        ])

        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_multipart_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        StorageSandbox.set_abort_multipart_upload_responses([
          {@bucket,
           fn ->
             {:ok,
              %{
                body: "",
                headers: [
                  {"x-amz-id-2",
                   "LQXU1lr7kVEJe+MIP6t5vM0rLN3mDSdTkRI3Mw0EV7QZQsSy2dWkO6SEdwxH1ZnLMZ9TBEQjXZ4="},
                  {"x-amz-request-id", "S8HCXECRERKT8F8S"},
                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                  {"server", "AmazonS3"}
                ],
                status_code: 204
              }}
           end}
        ])

        assert {:ok,
                %{
                  job: garbage_collect_object_job,
                  schema_data: abort_upload_schema_data
                }} = Uploader.abort_multipart_upload(MockUploader, %{id: schema_data.id})

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   key: ^expected_job_key,
                   uploader: "Uppy.UploaderTest.MockUploader"
                 }
               } = garbage_collect_object_job

        assert abort_upload_schema_data.id === schema_data.id

        # The record should not exists
        assert {:error, %{code: :not_found}} =
                 PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # after performing the job another job should be schedule that can
        # garbage collect the object if it was uploaded after expiration.
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          args: %{
            event: "uppy.garbage_collector.garbage_collect_object",
            uploader: "Uppy.UploaderTest.MockUploader",
            key: schema_data.key
          },
          queue: :garbage_collection
        )

        # storage head_object must return an ok response
        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        StorageSandbox.set_delete_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert :ok =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.garbage_collect_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })
      end)
    end
  end

  describe "&complete_multipart_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        StorageSandbox.set_initiate_multipart_upload_responses([
          {@bucket,
           fn object ->
             {:ok,
              %{
                key: object,
                bucket: @bucket,
                upload_id: "upload_id"
              }}
           end}
        ])

        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_multipart_upload(
                   MockUploader,
                   context.user.id,
                   %{
                     filename: @filename,
                     user_avatar_id: context.user_avatar.id,
                     user_id: context.user.id
                   },
                   []
                 )

        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: schema_data_id,
                 unique_identifier: schema_data_unique_identifier,
                 key: schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: schema_data_user_avatar_id,
                 user_id: schema_data_user_id,
                 # the object metadata fields should be nil
                 e_tag: nil,
                 upload_id: "upload_id",
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = schema_data

        assert schema_data_user_id === context.user.id
        assert schema_data_user_avatar_id === context.user_avatar.id
        assert schema_data_unique_identifier
        assert schema_data_key

        StorageSandbox.set_complete_multipart_upload_responses([
          {@bucket,
           fn ->
             {:ok,
              %{
                location: "https://s3.com/image.jpeg",
                bucket: @bucket,
                key: @filename,
                e_tag: @e_tag
              }}
           end}
        ])

        assert {:ok,
                %{
                  schema_data: complete_upload_schema_data,
                  job: run_pipeline_job,
                  metadata: %{
                    location: "https://s3.com/image.jpeg",
                    bucket: @bucket,
                    key: @filename,
                    e_tag: @e_tag
                  }
                }} =
                 Uploader.complete_multipart_upload(
                   MockUploader,
                   %{id: schema_data_id},
                   [{1, @e_tag}]
                 )

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = run_pipeline_job

        # e_tag should be the only new value set on the completed upload record
        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: complete_upload_schema_data_id,
                 unique_identifier: complete_upload_schema_data_unique_identifier,
                 key: complete_upload_schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: complete_upload_schema_data_user_avatar_id,
                 user_id: complete_upload_schema_data_user_id,
                 # object metadata fields except e_tag should be nil
                 e_tag: complete_upload_schema_data_e_tag,
                 upload_id: "upload_id",
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = complete_upload_schema_data

        assert is_binary(complete_upload_schema_data_e_tag)

        # these should be the starting values
        assert complete_upload_schema_data_id === schema_data_id

        assert complete_upload_schema_data_unique_identifier ===
                 schema_data_unique_identifier

        assert complete_upload_schema_data_key === schema_data_key

        assert complete_upload_schema_data_user_avatar_id ===
                 schema_data_user_avatar_id

        assert complete_upload_schema_data_user_id === context.user.id

        assert complete_upload_schema_data.id === schema_data_id

        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.PostProcessorWorker,
          args: %{
            event: "uppy.post_processor.run_pipeline",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data_id
          },
          queue: :post_processing
        )

        StorageSandbox.set_put_object_copy_responses([
          {
            @bucket,
            fn ->
              {:ok,
               %{
                 body: "body",
                 headers: [
                   {"x-amz-id-2", "amz_id"},
                   {"x-amz-request-id", "C6KG1R8WTNFSTX5F"},
                   {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
                   {"x-amz-server-side-encryption", "AES256"},
                   {"content-type", "application/xml"},
                   {"server", "AmazonS3"},
                   {"content-length", "224"}
                 ],
                 status_code: 200
               }}
            end
          }
        ])

        assert {:ok,
                %{
                  result:
                    %{
                      value: job_pipeline_schema_data,
                      context: %{
                        bucket: @bucket,
                        schema: @schema,
                        resource_name: @resource_name,
                        action_adapter: @action_adapter,
                        storage_adapter: @storage_adapter,
                        permanent_scope_adapter: @permanent_scope_adapter,
                        temporary_scope_adapter: @temporary_scope_adapter
                      },
                      private: job_pipeline_private
                    } = _input,
                  phases: [
                    Uppy.Pipeline.Phases.PutObjectCopy,
                    Uppy.Pipeline.Phases.EctoHolderLoader
                  ]
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.PostProcessorWorker, %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # pipeline result should match the input
        assert job_pipeline_schema_data.id === schema_data_id

        assert [
                 {
                   Elixir.Uppy.Pipeline.Phases.PutObjectCopy,
                   %{
                     basename: job_pipeline_private_basename,
                     metadata: @head_object_params,
                     schema_data:
                       %Uppy.Support.PG.Objects.UserAvatarObject{
                         e_tag: @e_tag,
                         archived: false,
                         archived_at: nil,
                         inserted_at: _,
                         updated_at: _
                       } = job_pipeline_private_schema_data,
                     partition_id: job_pipeline_partition_id,
                     destination_object: job_pipeline_destination_object,
                     source_object: job_pipeline_source_object
                   }
                 }
               ] = job_pipeline_private

        assert job_pipeline_partition_id === context.user.company_id

        assert job_pipeline_private_schema_data.upload_id === schema_data.upload_id
        assert job_pipeline_private_schema_data.id === schema_data.id
        assert job_pipeline_private_schema_data.user_id === context.user.id
        assert job_pipeline_private_schema_data.user_avatar_id === context.user_avatar.id

        expected_permanent_object =
          Enum.join([
            "#{String.reverse("#{context.user.company_id}")}-user-avatars/",
            "#{schema_data.unique_identifier}-#{schema_data.filename}"
          ])

        assert job_pipeline_private_schema_data.key === expected_permanent_object
        assert job_pipeline_destination_object === expected_permanent_object
        assert job_pipeline_source_object === schema_data.key

        assert job_pipeline_private_basename ===
                 "#{schema_data.unique_identifier}-#{schema_data.filename}"

        assert job_pipeline_private_schema_data.content_length ===
                 @head_object_params.content_length

        assert job_pipeline_private_schema_data.content_type === @head_object_params.content_type

        assert job_pipeline_private_schema_data.last_modified ===
                 @head_object_params.last_modified
      end)
    end
  end
end
