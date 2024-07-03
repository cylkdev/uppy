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

  @bucket "bucket"
  @resource "resource"
  @storage Uppy.Adapters.Storage.S3
  @scheduler Uppy.Adapters.Scheduler.Oban
  @queryable Uppy.Support.PG.Objects.UserAvatarObject
  @queryable_primary_key_source :id
  @parent_schema Uppy.Support.PG.Accounts.UserAvatar
  @parent_association_source :user_avatar_id
  @owner_schema PG.Accounts.User
  @owner_association_source :user_id
  @owner_primary_key_source :id
  @temporary_object_key Uppy.Adapters.ObjectKey.TemporaryObject
  @permanent_object_key Uppy.Adapters.ObjectKey.PermanentObject

  @core_params [
    bucket: @bucket,
    resource: @resource,
    storage: @storage,
    scheduler: @scheduler,
    queryable: @queryable,
    queryable_primary_key_source: @queryable_primary_key_source,
    parent_schema: @parent_schema,
    parent_association_source: @parent_association_source,
    owner_schema: @owner_schema,
    owner_association_source: @owner_association_source,
    owner_primary_key_source: @owner_primary_key_source,
    temporary_object_key: @temporary_object_key,
    permanent_object_key: @permanent_object_key
  ]

  defmodule MockUploader do
    use Uppy,
      # must be the same as the bucket in the test suite
      bucket: "bucket",
      resource: "user-avatars",
      storage: Uppy.Adapters.Storage.S3,
      scheduler: Uppy.Adapters.Scheduler.Oban,
      queryable: Uppy.Support.PG.Objects.UserAvatarObject,
      parent_schema: Uppy.Support.PG.Accounts.UserAvatar,
      parent_association_source: :user_avatar_id,
      owner_schema: Uppy.Support.PG.Accounts.User,
      owner_association_source: :user_id,
      owner_primary_key_source: :id,
      owner_partition_source: :company_id
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
    %{core: Core.validate!(@core_params)}
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
        filename = Faker.File.file_name()

        assert {:ok,
                %{
                  unique_identifier: unique_identifier,
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
        assert key

        # the key has the temporary path prefix and the temporary object key adapter
        # recognizes it as being in a temporary path.
        assert "temp/" <> _ = key
        assert context.core.temporary_object_key.path?(key: key)

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
        assert schema_data.filename === filename

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
                  job: garbage_collect_object_job,
                  schema_data: abort_upload_schema_data
                }} = Uploader.abort_upload(MockUploader, %{id: schema_data.id})

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
                  job: move_temporary_to_permanent_upload_job
                }} = Uploader.complete_upload(MockUploader, %{id: schema_data_id})

        assert complete_upload_metadata === @head_object_params

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.move_temporary_to_permanent_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = move_temporary_to_permanent_upload_job

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
            event: "uppy.post_processor.move_temporary_to_permanent_upload",
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
                    result: %{
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
                   event: "uppy.post_processor.move_temporary_to_permanent_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # job should return the upload record and owner
        assert job_schema_data.id === schema_data_id
        assert job_owner.id === context.user.id

        # pipeline result should match the input
        assert job_pipeline_destination_object === job_destination_object
        assert job_pipeline_source_object === job_source_object
        assert job_pipeline_schema_data.id === schema_data_id
        assert job_pipeline_owner.id === context.user.id
        assert job_pipeline_private === %{}
        assert job_pipeline_source_object === schema_data.key

        # validate the destination object key
        expected_id = String.reverse("#{context.user.id}")
        expected_resource = "user-avatars"
        expected_destination_basename = "#{schema_data.unique_identifier}-#{schema_data.filename}"

        expected_destination_object =
          "#{expected_id}-#{expected_resource}/#{expected_destination_basename}"

        assert job_pipeline_destination_object === expected_destination_object

        # the permanent object adapter should also pass
        assert Uppy.Adapters.ObjectKey.PermanentObject.path?(
                 key: job_pipeline_destination_object,
                 id: "#{context.user.id}",
                 resource: expected_resource
               )

        assert job_pipeline_destination_object ===
                 Uppy.Adapters.ObjectKey.PermanentObject.build(
                   id: "#{context.user.id}",
                   resource: expected_resource,
                   basename: expected_destination_basename
                 )
      end)
    end
  end

  describe "&start_multipart_upload/5" do
    @tag oban_testing: "manual"
    test "creates multipart upload, database record and lifecycle jobs", context do
      Oban.Testing.with_testing_mode(:manual, fn ->
        filename = Faker.File.file_name()

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
                   %{
                     owner_id: context.user.id,
                     assoc_id: context.user_avatar.id
                   },
                   %{filename: filename}
                 )

        # required parameters are not null
        assert unique_identifier
        assert multipart_upload_key === key

        # the key has the temporary path prefix and the temporary object key adapter
        # recognizes it as being in a temporary path.
        assert "temp/" <> _ = key
        assert context.core.temporary_object_key.path?(key: key)

        # the expected fields are set on the schema data
        assert %PG.Objects.UserAvatarObject{} = schema_data
        assert schema_data.unique_identifier === unique_identifier
        assert schema_data.key === key
        assert schema_data.filename === filename

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
        filename = Faker.File.file_name()

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
                   %{
                    owner_id: context.user.id,
                    assoc_id: context.user_avatar.id
                   },
                   %{filename: filename}
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
        filename = Faker.File.file_name()

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
                   %{
                    owner_id: context.user.id,
                    assoc_id: context.user_avatar.id
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
                key: "image.jpeg",
                e_tag: "e_tag"
              }}
           end}
        ])

        assert {:ok,
                %{
                  schema_data: complete_upload_schema_data,
                  job: move_temporary_to_permanent_upload_job,
                  metadata: %{
                    location: "https://s3.com/image.jpeg",
                    bucket: @bucket,
                    key: "image.jpeg",
                    e_tag: "e_tag"
                  }
                }} =
                 Uploader.complete_multipart_upload(
                   MockUploader,
                   %{id: schema_data_id},
                   [{1, "e_tag"}]
                 )

        assert %Oban.Job{
                 args: %{
                   event: "uppy.post_processor.move_temporary_to_permanent_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: ^schema_data_id
                 }
               } = move_temporary_to_permanent_upload_job

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
            event: "uppy.post_processor.move_temporary_to_permanent_upload",
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
                    result: %{
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
                   event: "uppy.post_processor.move_temporary_to_permanent_upload",
                   uploader: "Uppy.UploaderTest.MockUploader",
                   id: schema_data_id
                 })

        # job should return the upload record and owner
        assert job_schema_data.id === schema_data_id
        assert job_owner.id === context.user.id

        # pipeline result should match the input
        assert job_pipeline_destination_object === job_destination_object
        assert job_pipeline_source_object === job_source_object
        assert job_pipeline_schema_data.id === schema_data_id
        assert job_pipeline_owner.id === context.user.id
        assert job_pipeline_private === %{}
        assert job_pipeline_source_object === schema_data.key

        # validate the destination object key
        expected_id = String.reverse("#{context.user.id}")
        expected_resource = "user-avatars"
        expected_destination_basename = "#{schema_data.unique_identifier}-#{schema_data.filename}"

        expected_destination_object =
          "#{expected_id}-#{expected_resource}/#{expected_destination_basename}"

        assert job_pipeline_destination_object === expected_destination_object

        # the permanent object adapter should also pass
        assert Uppy.Adapters.ObjectKey.PermanentObject.path?(
                 key: job_pipeline_destination_object,
                 id: "#{context.user.id}",
                 resource: expected_resource
               )

        assert job_pipeline_destination_object ===
                 Uppy.Adapters.ObjectKey.PermanentObject.build(
                   id: "#{context.user.id}",
                   resource: expected_resource,
                   basename: expected_destination_basename
                 )
      end)
    end
  end
end
