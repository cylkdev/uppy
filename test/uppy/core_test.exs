defmodule Uppy.CoreTest do
  use Uppy.Support.DataCase, async: true

  alias Uppy.Core
  alias Uppy.Support.{Factory, PG,StorageSandbox}

  @schema Uppy.Support.PG.Objects.UserAvatarObject
  @resource_name "user-avatars"
  @source "user_avatar_objects"

  @schema_source_tuple {@schema, @source}

  @bucket "test_bucket"
  @filename "test_filename.txt"
  @unique_identifier "unique_identifier"

  @temporary_object_key_adapter Uppy.Adapters.TemporaryObjectKey

  @content_length 11
  @content_type "text/plain"
  @e_tag "etag"
  @last_modified ~U[2023-08-18 10:53:21Z]
  @storage_object_metadata %{
    content_length: @content_length,
    content_type: @content_type,
    e_tag: @e_tag,
    last_modified: @last_modified
  }

  setup do
    organization = FactoryEx.insert!(Factory.Accounts.Organization)
    user = FactoryEx.insert!(Factory.Accounts.User, %{organization_id: organization.id})
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})
    user_avatar = FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

    %{
      organization: organization,
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
            url: "https://url.com/#{object}",
            expires_at: DateTime.add(DateTime.utc_now(), 60_000)
          }}
       end}
    ])
  end

  describe "&complete_upload/7: " do
    test "updates the `:e_tag` and creates job to run the pipeline when the scheduler is enabled.", context do
      defmodule MockTestPipeline do
        def pipeline do
          [
            Uppy.Pipeline.Phases.ValidatePermanentObjectKey
          ]
        end
      end

      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      schema_data = FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
        unique_identifier: @unique_identifier,
        filename: @filename,
        key: expected_temporary_key,
        user_avatar_id: context.user_avatar.id,
        user_id: context.user.id
      })

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok, %{
        metadata: @storage_object_metadata,
        schema_data: schema_data,
        jobs: %{run_pipeline: run_pipeline_job}
      }} =
        Core.complete_upload(
          @bucket,
          @resource_name,
          MockTestPipeline,
          @schema_source_tuple,
          schema_data
        )

      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        key: ^expected_temporary_key
      } = schema_data

      expected_run_pipeline_job_args =
        %{
          bucket: @bucket,
          event: "uppy.post_processing_worker.run_pipeline",
          id: schema_data.id,
          pipeline: "Uppy.CoreTest.MockTestPipeline",
          resource_name: @resource_name,
          schema: inspect(@schema),
          source: @source
        }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Adapters.Scheduler.Oban.PostProcessingWorker",
        args: ^expected_run_pipeline_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = run_pipeline_job

      assert_enqueued(
        worker: Uppy.Adapters.Scheduler.Oban.PostProcessingWorker,
        args: expected_run_pipeline_job_args,
        queue: :post_processing
      )

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {
        :ok,
        %{
          output: %{
            options: [],
            context: %{},
            schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
              id: ^schema_data_id,
              user_id: ^user_id,
              user_avatar_id: ^user_avatar_id,
              unique_identifier: @unique_identifier,
              key: ^expected_temporary_key,
              filename: @filename,
              e_tag: @e_tag,
              upload_id: nil,
              # metadata should be nil as file is not processed yet
              content_length: nil,
              content_type: nil,
              last_modified: nil,
              archived: false,
              archived_at: nil
            },
            schema: {Uppy.Support.PG.Objects.UserAvatarObject, "user_avatar_objects"},
            resource_name: "user-avatars",
            bucket: "test_bucket"
          },
          phases: [Uppy.Pipeline.Phases.ValidatePermanentObjectKey]
        }
      } =
        perform_job(
          Uppy.Adapters.Scheduler.Oban.PostProcessingWorker,
          expected_run_pipeline_job_args
        )
    end
  end

  describe "&abort_upload/4: " do
    test "deletes a upload record and creates job to garbage collect the object when the scheduler is enabled.", context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      schema_data = FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
        unique_identifier: @unique_identifier,
        filename: @filename,
        key: expected_temporary_key,
        user_avatar_id: context.user_avatar.id,
        user_id: context.user.id
      })

      assert {:ok, %{
        schema_data: abort_upload_schema_data,
        jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
      }} = Core.abort_upload(@bucket, @schema_source_tuple, schema_data)

      # should be the same database record
      assert abort_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{id: schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: "user_avatar_objects",
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: "test_bucket"
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker",
        args: ^expected_delete_object_if_upload_not_found_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_object_if_upload_not_found_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
        args: expected_delete_object_if_upload_not_found_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          expected_delete_object_if_upload_not_found_job_args
        )
    end
  end

  describe "&start_upload/5: " do
    test "creates a upload and a job to abort the upload and garbage collect the object when the scheduler is enabled.", context do
      assert {:ok, %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data,
        jobs: %{abort_upload: abort_upload_job}
      }} =
        Core.start_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: @filename,
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          }
        )

      # key should be in the temporary path
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{basename}"

      assert ^expected_temporary_key = temporary_key

      assert Uppy.TemporaryObjectKeys.validate_path(@temporary_object_key_adapter, temporary_key)

      assert ^basename = "#{unique_identifier}-#{schema_data.filename}"

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^expected_temporary_key,
        filename: @filename
      } = schema_data

      # the presigned upload payload contains a valid key, url and expiration
      assert String.contains?(presigned_upload.url, temporary_key)
      assert DateTime.compare(presigned_upload.expires_at, DateTime.utc_now()) === :gt

      expected_abort_upload_job_args =
        %{
          id: schema_data.id,
          source: "user_avatar_objects",
          schema: "Uppy.Support.PG.Objects.UserAvatarObject",
          event: "uppy.abort_upload_worker.abort_upload",
          bucket: "test_bucket"
        }

      assert %Oban.Job{
        state: "available",
        queue: "abort_upload",
        worker: "Uppy.Adapters.Scheduler.Oban.AbortUploadWorker",
        args: ^expected_abort_upload_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = abort_upload_job

      # a job should be scheduled to abort and only abort if it's a temporary object.
      # If the upload is already processed and permanently stored it must be deleted.

      expected_abort_upload_job_args = %{
        event: "uppy.abort_upload_worker.abort_upload",
        bucket: @bucket,
        schema: inspect(@schema),
        source: @source,
        id: schema_data.id
      }

      assert_enqueued(
        worker: Uppy.Adapters.Scheduler.Oban.AbortUploadWorker,
        args: expected_abort_upload_job_args,
        queue: :abort_upload
      )

      assert {:ok, %{
        schema_data: abort_upload_schema_data,
        jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
      }} =
        perform_job(
          Uppy.Adapters.Scheduler.Oban.AbortUploadWorker,
          expected_abort_upload_job_args
        )

      # should be the same database record
      assert abort_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{id: schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: "user_avatar_objects",
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: "test_bucket"
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker",
        args: ^expected_delete_object_if_upload_not_found_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_object_if_upload_not_found_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
        args: expected_delete_object_if_upload_not_found_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker,
          expected_delete_object_if_upload_not_found_job_args
        )
    end

    test "creates a upload without job when the scheduler is disabled.", context do
      assert {:ok, %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data
      } = response} =
        Core.start_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: @filename,
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          },
          scheduler_enabled?: false
        )

      # jobs should not be present
      refute response[:jobs]

      # key should be in the temporary path
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{basename}"

      assert ^expected_temporary_key = temporary_key

      assert Uppy.TemporaryObjectKeys.validate_path(@temporary_object_key_adapter, temporary_key)

      assert ^basename = "#{unique_identifier}-#{schema_data.filename}"

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^expected_temporary_key,
        filename: @filename
      } = schema_data

      # the presigned upload payload contains a valid key, url and expiration
      assert String.contains?(presigned_upload.url, temporary_key)
      assert DateTime.compare(presigned_upload.expires_at, DateTime.utc_now()) === :gt
    end
  end
end
