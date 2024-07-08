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

  @actions_adapter Uppy.Adapters.Actions
  @storage_adapter Uppy.Adapters.Storage.S3
  @permanent_scope_adapter Uppy.Adapters.PermanentScope
  @temporary_scope_adapter Uppy.Adapters.TemporaryScope

  # @queryable Uppy.Support.PG.Objects.UserAvatarObject

  # @resource "resource"
  # @scheduler Uppy.Adapters.Scheduler.Oban
  # @queryable_primary_key_source :id
  # @parent_schema Uppy.Support.PG.Accounts.UserAvatar
  # @parent_association_source :user_avatar_id
  # @owner_schema PG.Accounts.User
  # @owner_association_source :user_id
  # @owner_primary_key_source :id
  # @temporary_object_key Uppy.Adapters.PermanentScopes
  # @permanent_object_key Uppy.Adapters.PermanentScopes

  defmodule MockUploader do
    use Uppy.Uploader,
      bucket: "bucket",
      resource_name: "user-avatars",
      queryable: Uppy.Support.PG.Objects.UserAvatarObject
  end

  @head_object_params %{
    content_length: 11,
    content_type: "text/plain",
    e_tag: "etag",
    last_modified: ~U[2023-08-18 10:53:21Z]
  }

  setup do
    user = FactoryEx.insert!(Factory.Accounts.User)
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})

    user_avatar =
      FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

    %{
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

  describe "&confirm_upload/3" do
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
                  schema_data: confirm_upload_schema_data,
                  metadata: confirm_upload_metadata,
                  job: run_pipeline_job
                }} = Uploader.confirm_upload(MockUploader, %{id: schema_data_id}, [])

        assert confirm_upload_metadata === @head_object_params

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = run_pipeline_job

        # e_tag should be the only new value set on the completed upload record
        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: confirm_upload_schema_data_id,
                 unique_identifier: confirm_upload_schema_data_unique_identifier,
                 key: confirm_upload_schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: confirm_upload_schema_data_user_avatar_id,
                 user_id: confirm_upload_schema_data_user_id,
                 # object metadata fields except e_tag should be nil
                 e_tag: confirm_upload_schema_data_e_tag,
                 upload_id: nil,
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = confirm_upload_schema_data

        assert is_binary(confirm_upload_schema_data_e_tag)

        # these should be the starting values
        assert confirm_upload_schema_data_id === schema_data_id

        assert confirm_upload_schema_data_unique_identifier ===
                 schema_data_unique_identifier

        assert confirm_upload_schema_data_key === schema_data_key

        assert confirm_upload_schema_data_user_avatar_id ===
                 schema_data_user_avatar_id

        assert confirm_upload_schema_data_user_id === context.user.id

        assert confirm_upload_schema_data.id === schema_data_id

        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.PostProcessorWorker,
          args: %{
            event: "uppy.post_processor.run_pipeline",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data_id
          },
          queue: :post_processing
        )

        assert {:ok,
                %{
                  result: %{
                    actions_adapter: @actions_adapter,
                    storage_adapter: @storage_adapter,
                    bucket: @bucket,
                    resource_name: @resource_name,
                    temporary_scope_adapter: @temporary_scope_adapter,
                    permanent_scope_adapter: @permanent_scope_adapter,
                    schema_data: job_pipeline_schema_data,
                    private: job_pipeline_private,
                    options: []
                  },
                  phases: []
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.PostProcessorWorker, %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # pipeline result should match the input
        assert job_pipeline_schema_data.id === schema_data_id
        assert job_pipeline_private === %{}
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

  describe "&confirm_multipart_upload/3" do
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

        StorageSandbox.set_confirm_multipart_upload_responses([
          {@bucket,
           fn ->
             {:ok,
              %{
                location: "https://s3.com/image.jpeg",
                bucket: @bucket,
                key: "image.jpeg",
                e_tag: "e_tag"
              }}
           end}
        ])

        assert {:ok,
                %{
                  schema_data: confirm_upload_schema_data,
                  job: run_pipeline_job,
                  metadata: %{
                    location: "https://s3.com/image.jpeg",
                    bucket: @bucket,
                    key: "image.jpeg",
                    e_tag: "e_tag"
                  }
                }} =
                 Uploader.confirm_multipart_upload(
                   MockUploader,
                   %{id: schema_data_id},
                   [{1, "e_tag"}]
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
                 id: confirm_upload_schema_data_id,
                 unique_identifier: confirm_upload_schema_data_unique_identifier,
                 key: confirm_upload_schema_data_key,
                 filename: @filename,
                 archived: false,
                 archived_at: nil,
                 user_avatar_id: confirm_upload_schema_data_user_avatar_id,
                 user_id: confirm_upload_schema_data_user_id,
                 # object metadata fields except e_tag should be nil
                 e_tag: confirm_upload_schema_data_e_tag,
                 upload_id: "upload_id",
                 content_length: nil,
                 content_type: nil,
                 last_modified: nil
               } = confirm_upload_schema_data

        assert is_binary(confirm_upload_schema_data_e_tag)

        # these should be the starting values
        assert confirm_upload_schema_data_id === schema_data_id

        assert confirm_upload_schema_data_unique_identifier ===
                 schema_data_unique_identifier

        assert confirm_upload_schema_data_key === schema_data_key

        assert confirm_upload_schema_data_user_avatar_id ===
                 schema_data_user_avatar_id

        assert confirm_upload_schema_data_user_id === context.user.id

        assert confirm_upload_schema_data.id === schema_data_id

        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.PostProcessorWorker,
          args: %{
            event: "uppy.post_processor.run_pipeline",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data_id
          },
          queue: :post_processing
        )

        assert {:ok,%{
          result: %{
            actions_adapter: @actions_adapter,
            storage_adapter: @storage_adapter,
            bucket: @bucket,
            resource_name: @resource_name,
            temporary_scope_adapter: @temporary_scope_adapter,
            permanent_scope_adapter: @permanent_scope_adapter,
            schema_data: job_pipeline_schema_data,
            private: job_pipeline_private,
            options: []
          },
          phases: []
        }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.PostProcessorWorker, %{
                   event: "uppy.post_processor.run_pipeline",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

          # pipeline result should match the input
        assert job_pipeline_schema_data.id === schema_data_id
        assert job_pipeline_private === %{}
      end)
    end
  end
end
