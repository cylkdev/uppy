defmodule Uppy.UploaderTest do
  use Uppy.Support.DataCase, async: true

  doctest Uppy.Uploader

  alias Uppy.{
    Core,
    Support.Factory,
    Support.PG,
    Support.StorageSandbox,
    Uploader
  }

  @bucket "test_bucket"
  @resource_name "test-resource-name"
  @storage_adapter Uppy.Adapters.Storage.S3
  @scheduler_adapter Uppy.Adapters.Scheduler.Oban
  @temporary_object_key_adapter Uppy.Adapters.ObjectKey.TemporaryObject
  @permanent_object_key_adapter Uppy.Adapters.ObjectKey.PermanentObject
  @parent_schema Uppy.Support.PG.Accounts.UserAvatar
  @parent_association_source :user_avatar_id
  @queryable_primary_key_source :id
  @owner_schema PG.Accounts.User
  @queryable_owner_association_source :user_id
  @owner_primary_key_source :id

  @provider_options [
    bucket: @bucket,
    resource_name: @resource_name,
    storage_adapter: @storage_adapter,
    scheduler_adapter: @scheduler_adapter,
    temporary_object_key_adapter: @temporary_object_key_adapter,
    permanent_object_key_adapter: @permanent_object_key_adapter,
    parent_schema: @parent_schema,
    parent_association_source: @parent_association_source,
    queryable_primary_key_source: @queryable_primary_key_source,
    owner_schema: @owner_schema,
    queryable_owner_association_source: @queryable_owner_association_source,
    owner_primary_key_source: @owner_primary_key_source
  ]

  defmodule MockUploader do
    use Uppy.Uploader,
      bucket: "test_bucket",
      resource_name: "user-avatars",
      storage_adapter: Uppy.Adapters.Storage.S3,
      scheduler_adapter: Uppy.Adapters.Scheduler.Oban,
      queryable: Uppy.Support.PG.Objects.UserAvatarObject,
      parent_schema: Uppy.Support.PG.Accounts.UserAvatar,
      parent_association_source: :user_avatar_id,
      owner_schema: Uppy.Support.PG.Accounts.User,
      queryable_owner_association_source: :user_id,
      owner_primary_key_source: :id
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
    %{core: Core.validate!(@provider_options)}
  end

  setup do
    StorageSandbox.set_presigned_upload_responses([
      {@bucket,
       fn object ->
         {:ok,
          %{
            key: object,
            url: "http://presigned.url/#{object}",
            expires_at: DateTime.add(DateTime.utc_now(), 60_000)
          }}
       end}
    ])
  end

  describe "&start_upload/4" do
    @tag oban_testing: "manual"
    test "creates presigned upload, database record and lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        filename = Faker.File.file_name()

        assert {:ok,
                %{
                  unique_identifier: unique_identifier,
                  filename: filename,
                  key: key,
                  presigned_upload: presigned_upload,
                  schema_data: schema_data
                }} =
                 Uploader.start_upload(
                   MockUploader,
                   %{
                     assoc_id: context.user_avatar.id,
                     owner_id: context.user.id
                   },
                   %{filename: filename}
                 )

        # required parameters are not null
        assert unique_identifier
        assert filename
        assert key

        # the key has the temporary path prefix and the temporary object key adapter
        # recognizes it as being in a temporary path.
        assert "temp/" <> _ = key
        assert context.core.temporary_object_key_adapter.path?(key: key)

        # the presigned upload payload contains a valid key, url and expiration
        assert %{
                 key: presigned_upload_key,
                 url: presigned_upload_url,
                 expires_at: presigned_upload_expires_at
               } = presigned_upload

        assert presigned_upload_key === key
        assert String.contains?(presigned_upload_url, key)
        assert DateTime.compare(presigned_upload_expires_at, DateTime.utc_now()) === :gt

        # the expected fields are set on the schema data
        assert %PG.Objects.UserAvatarObject{} = schema_data
        assert schema_data.unique_identifier === unique_identifier
        assert schema_data.key === key
        assert schema_data.filename === filename

        # sanity check the record exists
        assert {:ok, _} = PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # job is scheduled that deletes the record

        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.ExpiredUploadAborterWorker,
          args: %{
            event: "uppy.expired_upload_aborter.abort_upload",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data.id
          },
          queue: :expired_uploads
        )

        assert {:ok,
                %{
                  delete_aborted_upload_object_job: delete_aborted_upload_object_job,
                  schema_data: abort_upload_job_schema_data
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.ExpiredUploadAborterWorker, %{
                   event: "uppy.expired_upload_aborter.abort_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data.id
                 })

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.delete_aborted_upload_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: ^expected_job_key
                 }
               } = delete_aborted_upload_object_job

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
            event: "uppy.garbage_collector.delete_aborted_upload_object",
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

        assert {:ok, delete_aborted_upload_object_payload} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.delete_aborted_upload_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })

        assert delete_aborted_upload_object_payload === @head_object_params
      end)
    end
  end

  describe "&abort_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        filename = Faker.File.file_name()

        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_upload(
                   MockUploader,
                   %{
                     assoc_id: context.user_avatar.id,
                     owner_id: context.user.id
                   },
                   %{filename: filename}
                 )

        assert {:ok,
                %{
                  delete_aborted_upload_object_job: delete_aborted_upload_object_job,
                  schema_data: abort_upload_schema_data
                }} = Uploader.abort_upload(MockUploader, %{id: schema_data.id})

        expected_job_key = schema_data.key

        assert %Oban.Job{
                 args: %{
                   event: "uppy.garbage_collector.delete_aborted_upload_object",
                   key: ^expected_job_key,
                   uploader: "Uppy.UploaderTest.MockUploader"
                 }
               } = delete_aborted_upload_object_job

        assert abort_upload_schema_data.id === schema_data.id

        # The record should not exists
        assert {:error, %{code: :not_found}} =
                 PG.Objects.find_user_avatar_object(%{id: schema_data.id})

        # after performing the job another job should be schedule that can
        # garbage collect the object if it was uploaded after expiration.
        assert_enqueued(
          worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          args: %{
            event: "uppy.garbage_collector.delete_aborted_upload_object",
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

        assert {:ok, delete_aborted_upload_object_payload} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker, %{
                   event: "uppy.garbage_collector.delete_aborted_upload_object",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   key: schema_data.key
                 })

        assert delete_aborted_upload_object_payload === @head_object_params
      end)
    end
  end

  describe "&complete_upload/3" do
    @tag oban_testing: "manual"
    test "deletes record if key in temp path and creates lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        filename = Faker.File.file_name()

        assert {:ok, %{schema_data: schema_data}} =
                 Uploader.start_upload(
                   MockUploader,
                   %{
                     assoc_id: context.user_avatar.id,
                     owner_id: context.user.id
                   },
                   %{filename: filename}
                 )

        StorageSandbox.set_head_object_responses([
          {@bucket, fn -> {:ok, @head_object_params} end}
        ])

        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: schema_data_id,
                 unique_identifier: schema_data_unique_identifier,
                 key: schema_data_key,
                 filename: ^filename,
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
                  move_upload_to_permanent_storage_job:
                    complete_upload_move_upload_to_permanent_storage_job
                }} = Uploader.complete_upload(MockUploader, %{id: schema_data_id})

        assert complete_upload_metadata === @head_object_params

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.move_upload_to_permanent_storage",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = complete_upload_move_upload_to_permanent_storage_job

        # e_tag should be the only new value set on the completed upload record
        assert %Uppy.Support.PG.Objects.UserAvatarObject{
                 id: complete_upload_schema_data_id,
                 unique_identifier: complete_upload_schema_data_unique_identifier,
                 key: complete_upload_schema_data_key,
                 filename: ^filename,
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
            event: "uppy.post_processor.move_upload_to_permanent_storage",
            uploader: "Uppy.UploaderTest.MockUploader",
            id: schema_data_id
          },
          queue: :post_processing
        )

        assert {:ok,
                %{
                  destination_object: job_destination_object,
                  source_object: job_source_object,
                  schema_data: job_schema_data,
                  owner: job_owner,
                  pipeline: %{
                    output: %{
                      schema_data: job_pipeline_schema_data,
                      owner: job_pipeline_owner,
                      destination_object: job_pipeline_destination_object,
                      source_object: job_pipeline_source_object,
                      private: job_pipeline_private,
                      options: []
                    },
                    phases: []
                  }
                }} =
                 perform_job(Uppy.Adapters.Scheduler.Oban.PostProcessorWorker, %{
                   event: "uppy.post_processor.move_upload_to_permanent_storage",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # job should return the upload record and owner
        assert job_schema_data.id === schema_data_id
        assert job_owner.id === context.user.id

        # pipeline output should match the input
        assert job_pipeline_destination_object === job_destination_object
        assert job_pipeline_source_object === job_source_object
        assert job_pipeline_schema_data.id === schema_data_id
        assert job_pipeline_owner.id === context.user.id
        assert job_pipeline_private === %{}
        assert job_pipeline_source_object === schema_data.key

        # validate the destination object key
        expected_id = String.reverse("#{context.user.id}")
        expected_resource_name = "user-avatars"
        expected_destination_basename = "#{schema_data.unique_identifier}-#{schema_data.filename}"

        expected_destination_object =
          "#{expected_id}-#{expected_resource_name}/#{expected_destination_basename}"

        assert job_pipeline_destination_object === expected_destination_object

        # the permanent object adapter should also pass
        assert Uppy.Adapters.ObjectKey.PermanentObject.path?(
                 key: job_pipeline_destination_object,
                 id: "#{context.user.id}",
                 resource_name: expected_resource_name
               )

        assert job_pipeline_destination_object ===
                 Uppy.Adapters.ObjectKey.PermanentObject.build(
                   id: "#{context.user.id}",
                   resource_name: expected_resource_name,
                   basename: expected_destination_basename
                 )
      end)
    end
  end
end
