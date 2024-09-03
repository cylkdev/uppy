defmodule Uppy.CoreAbstractSchemaTest do
  use Uppy.Support.DataCase, async: true

  @moduletag :external

  alias Uppy.{
    Action,
    Core,
    PathBuilder
  }

  alias Uppy.Support.{
    Factory,
    PG,
    StorageSandbox
  }

  @schema Uppy.Support.PG.Objects.UserAvatarObject
  @source "user_avatar_objects"

  @schema_source_tuple {@schema, @source}

  @resource "user-avatars"

  @bucket "uppy-test"
  @filename "example.txt"
  @unique_identifier "test_unique_identifier"
  @upload_id "test_upload_id"

  defmodule MockPipeline do
    def phases(opts \\ []) do
      [{Uppy.Phases.ValidateObjectTemporaryPath, opts}]
    end
  end

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
            expires_at: ~U[2024-07-24 02:51:32.453714Z]
          }}
       end}
    ])
  end

  describe "&find_permanent_multipart_upload/2" do
    test "returns a record if :e_tag is not nil and :key is a permanent object key.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      permanent_key = "#{user_id}-uploads/user-avatars/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: permanent_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag",
          upload_id: @upload_id
        })

      assert {:ok, found_schema_data} =
        Core.find_permanent_multipart_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert schema_data.id === found_schema_data.id
    end
  end

  describe "&find_completed_multipart_upload/2" do
    test "returns a record when `:e_tag` is not nil", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag",
          upload_id: @upload_id
        })

      assert {:ok, found_schema_data} =
        Core.find_completed_multipart_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert schema_data.id === found_schema_data.id
    end
  end

  describe "&find_temporary_multipart_upload/2" do
    test "returns record when `:e_tag` is not nil and `:key` is a temporary object key", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      assert {:ok, found_schema_data} =
        Core.find_temporary_multipart_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert schema_data.id === found_schema_data.id
    end
  end

  describe "&find_parts/5" do
    test "returns the parts for a multipart upload", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      StorageSandbox.set_list_parts_responses([
        {
          @bucket,
          fn ->
            {:ok, [
              %{
                size: 1,
                etag: "etag",
                part_number: 1
              }
            ]}
          end
        }
      ])

      assert {:ok, response} =
        Core.find_parts(
          @bucket,
          @schema_source_tuple,
          %{id: schema_data_id}
        )

      assert %{
        parts: parts,
        schema_data: schema_data
      } = response

      assert [
        %{
          size: 1,
          etag: "etag",
          part_number: 1
        }
      ] = parts

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^user_id,
        user_avatar_id: ^user_avatar_id,
        unique_identifier: @unique_identifier,
        key: ^temporary_key,
        filename: "example.txt",
        e_tag: nil,
        upload_id: @upload_id,
        content_length: nil,
        content_type: nil,
        last_modified: nil,
        archived: false,
        archived_at: nil
      } = schema_data
    end
  end

  describe "&presigned_part/5" do
    test "returns presigned url payload and schema data", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      presigned_url = "https://url.com/#{temporary_key}"

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, response} =
        Core.presigned_part(
          @bucket,
          @schema_source_tuple,
          %{id: schema_data_id},
          1
        )

      assert %{
        presigned_part: presigned_part,
        schema_data: schema_data
      } = response

      assert %{
        url: ^presigned_url,
        expires_at: ~U[2024-07-24 02:51:32.453714Z]
      } = presigned_part

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^user_id,
        user_avatar_id: ^user_avatar_id,
        unique_identifier: @unique_identifier,
        key: ^temporary_key,
        filename: "example.txt",
        e_tag: nil,
        upload_id: @upload_id,
        content_length: nil,
        content_type: nil,
        last_modified: nil,
        archived: false,
        archived_at: nil
      } = schema_data
    end
  end

  describe "&complete_multipart_upload/7" do
    test "updates :e_tag and creates a pipeline job when schema_data is provided and the scheduler is enabled.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              location: "https://s3.com/#{temporary_key}",
              bucket: @bucket,
              key: temporary_key,
              e_tag: "etag"
            }}
         end}
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      assert {:ok, response} =
        Core.complete_multipart_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          schema_data,
          %{},
          [{1, "etag"}]
        )

      assert %{
        metadata: metadata,
        schema_data: schema_data,
        jobs: %{
          process_upload: process_upload_job
        }
      } = response

      assert %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "etag",
        last_modified: ~U[2023-08-18 10:53:21Z]
      } = metadata

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        key: ^temporary_key,
        e_tag: "etag"
      } = schema_data

      job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockPipeline",
        resource: @resource,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects"
      }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
        args: ^job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = process_upload_job

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.PostProcessingWorker,
        args: job_args,
        queue: :post_processing
      )

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, job_response} =
        perform_job(
          Uppy.Schedulers.Oban.PostProcessingWorker,
          job_args
        )

      assert {input, phases} = job_response

      assert %Uppy.Pipeline.Input{
        schema_data: input_schema_data,
        schema: Uppy.Support.PG.Objects.UserAvatarObject,
        source: "user_avatar_objects",
        resource: "user-avatars",
        bucket: @bucket
      } = input

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^user_id,
        user_avatar_id: ^user_avatar_id,
        unique_identifier: @unique_identifier,
        key: ^temporary_key,
        filename: "example.txt",
        e_tag: "etag",
        upload_id: @upload_id,
        # metadata should be nil as file is not processed yet
        content_length: nil,
        content_type: nil,
        last_modified: nil,
        archived: false,
        archived_at: nil
      } = input_schema_data

      assert [Uppy.Phases.ValidateObjectTemporaryPath] = phases
    end

    test "updates the `:e_tag and creates pipeline job when given a `schema` module and `params` map as an argument and the scheduler is enabled", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:ok, %{
              location: "https://s3.com/#{temporary_key}",
              bucket: @bucket,
              key: temporary_key,
              e_tag: "etag"
            }}
          end
        }
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      assert {:ok, response} =
        Core.complete_multipart_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          %{id: schema_data.id},
          %{},
          [{1, "etag"}]
        )

      assert %{
        metadata: metadata,
        schema_data: schema_data,
        jobs: %{process_upload: process_upload_job}
      } = response

      assert %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "etag",
        last_modified: ~U[2023-08-18 10:53:21Z]
      } = metadata

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        key: ^temporary_key,
        e_tag: "etag"
      } = schema_data

      job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockPipeline",
        resource: @resource,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects"
      }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
        args: ^job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = process_upload_job
    end

    test "can complete already completed multipart upload", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      assert {:ok, response} =
        Core.complete_multipart_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          %{id: schema_data.id},
          %{},
          [{1, "etag"}]
        )

      assert %{
        metadata: metadata,
        schema_data: schema_data,
        jobs: %{
          process_upload: process_upload_job
        }
      } = response

      assert %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "etag",
        last_modified: ~U[2023-08-18 10:53:21Z]
      } = metadata

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        key: ^temporary_key,
        e_tag: "etag"
      } = schema_data

      job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockPipeline",
        resource: @resource,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
      }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
        args: ^job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = process_upload_job
    end

    test "returns unhandled error", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :internal_server_error}} end}
      ])

      assert {:error, %{code: :internal_server_error}} =
        Core.complete_multipart_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          %{id: schema_data.id},
          %{},
          [{1, "etag"}]
        )
    end
  end

  describe "&abort_multipart_upload/4" do
    test "deletes record and creates job to garbage collect the object when the scheduler is enabled.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_abort_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:ok,
             %{
               body: "",
               headers: [
                 {"x-amz-id-2", "<x-amz-id-2>"},
                 {"x-amz-request-id", "<x-amz-request-id>"},
                 {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                 {"server", "AmazonS3"}
               ],
               status_code: 204
             }}
          end
        }
      ])

      assert {:ok, response} =
        Core.abort_multipart_upload(
          @bucket,
          @schema_source_tuple,
          schema_data
        )

      assert %{
        schema_data: abort_multipart_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = response

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{
          id: schema_data.id
        })

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_not_found_object_job_args = %{
        key: temporary_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^expected_delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
        args: expected_delete_not_found_object_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Schedulers.Oban.GarbageCollectorWorker,
          expected_delete_not_found_object_job_args
        )
    end

    test "can abort an already aborted upload, delete the record and create a job to garbage collect the object when the scheduler is enabled.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_abort_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      assert {:ok, response} =
        Core.abort_multipart_upload(
          @bucket,
          @schema_source_tuple,
          schema_data
        )

      assert %{
        schema_data: abort_multipart_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = response

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{id: schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_not_found_object_job_args = %{
        key: temporary_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^expected_delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job
    end

    test "returns unhandled error", context do
      partition_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{partition_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_abort_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :internal_server_error}} end}
      ])

      assert {:error, %{code: :internal_server_error}} =
        Core.abort_multipart_upload(
          @bucket,
          @schema_source_tuple,
          schema_data
        )
    end
  end

  describe "&start_multipart_upload/5" do
    test "initializes a multipart upload, creates a database record, and schedules both its deletion after expiration and a garbage collection job after the record is deleted.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      StorageSandbox.set_initiate_multipart_upload_responses([
        {
          @bucket,
          fn object ->
            {:ok, %{
              key: object,
              bucket: @bucket,
              upload_id: @upload_id
            }}
          end
        }
      ])

      assert {:ok, response} =
        Core.start_multipart_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: "example.txt",
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          }
        )

      assert %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        multipart_upload: multipart_upload,
        schema_data: schema_data,
        jobs: %{
          abort_multipart_upload: abort_multipart_upload_job
        }
      } = response

      assert :ok = PathBuilder.validate_temporary_path(temporary_key)

      assert ^basename = "#{unique_identifier}-#{schema_data.filename}"

      expected_temporary_key = "temp/#{user_id}-user/#{schema_data.unique_identifier}-example.txt"

      assert ^expected_temporary_key = temporary_key

      assert %{
        key: ^temporary_key,
        bucket: @bucket,
        upload_id: @upload_id
      } = multipart_upload

      # upload id should be stored
      assert schema_data.upload_id === @upload_id

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^temporary_key,
        filename: @filename
      } = schema_data

      abort_multipart_upload_job_args = %{
        id: schema_data.id,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.abort_upload_worker.abort_multipart_upload",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "abort_upload",
        worker: "Uppy.Schedulers.Oban.AbortUploadWorker",
        args: ^abort_multipart_upload_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = abort_multipart_upload_job

      # a job should be scheduled to abort and only abort if it's a temporary object.
      # If the upload is already processed and permanently stored it must be deleted.

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.AbortUploadWorker,
        args: abort_multipart_upload_job_args,
        queue: :abort_upload
      )

      StorageSandbox.set_abort_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:ok, %{
              body: "",
              headers: [
                {"x-amz-id-2", "<x-amz-id-2>"},
                {"x-amz-request-id", "<x-amz-request-id>"},
                {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                {"server", "AmazonS3"}
              ],
              status_code: 204
            }}
          end
        }
      ])

      assert {:ok, response} =
        perform_job(
          Uppy.Schedulers.Oban.AbortUploadWorker,
          abort_multipart_upload_job_args
        )

      assert %{
        schema_data: abort_multipart_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = response

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{
          id: schema_data.id
        })

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      delete_not_found_object_job_args = %{
        key: temporary_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
        args: delete_not_found_object_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Schedulers.Oban.GarbageCollectorWorker,
          delete_not_found_object_job_args
        )
    end

    test "creates a record only when the scheduler is disabled.", context do
      user_id = PathBuilder.encode_id(context.user.id)

      StorageSandbox.set_initiate_multipart_upload_responses([
        {
          @bucket,
          fn object ->
            {:ok, %{
              key: object,
              bucket: @bucket,
              upload_id: @upload_id
            }}
          end
        }
      ])

      assert {:ok, response} =
        Core.start_multipart_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: "example.txt",
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          },
          scheduler_enabled?: false
        )

      assert %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        multipart_upload: multipart_upload,
        schema_data: schema_data
      } = response

      assert :ok = PathBuilder.validate_temporary_path(temporary_key)

      assert ^basename = "#{unique_identifier}-#{schema_data.filename}"

      expected_temporary_key = "temp/#{user_id}-user/#{schema_data.unique_identifier}-example.txt"

      assert ^expected_temporary_key = temporary_key

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^temporary_key,
        filename: @filename
      } = schema_data

      assert %{
        key: ^temporary_key,
        bucket: @bucket,
        upload_id: @upload_id
      } = multipart_upload

      # jobs should not be present
      refute response[:jobs]
    end
  end

  describe "&process_upload/6: " do
    test "copies image to destination with a resolution up to 1024 x 1024 and less than 5 MB", context do
      user_id = PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      # The phase `Uppy.Phases.HeadTemporaryObject` retrieves the metadata from
      # storage and adds it to the context for other phases in the pipeline.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      # The phase `Uppy.Phases.FileInfo` downloads the first 256 bytes of the object.
      file_header_chunk =
        File.cwd!()
        |> Path.join('/test_data/image_1024_1024_art_LT_3MB.png')
        |> File.stream!([:raw], Uppy.Phases.FileInfo.default_end_byte())
        |> Enum.take(1)

      StorageSandbox.set_get_chunk_responses([
        {@bucket, fn -> {:ok, file_header_chunk} end}
      ])

      # The phase `Uppy.Phases.PutPermanentObjectCopy` puts a copy
      # of the temporary object in storage.
      StorageSandbox.set_put_object_copy_responses([
        {
          ~r|.*|,
          fn ->
            {:ok, %{
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

      # The phase `Uppy.Phases.PutPermanentObjectCopy` is omitted from
      # the pipeline
      pipeline = Uppy.Pipeline.for_post_processing()

      assert {:ok, {input, _returned_phases}} =
        Core.process_upload(
          pipeline,
          @bucket,
          @resource,
          @schema_source_tuple,
          schema_data
        )

      assert %Uppy.Pipeline.Input{
        bucket: @bucket,
        resource: @resource,
        schema: Uppy.Support.PG.Objects.UserAvatarObject,
        source: "user_avatar_objects",
        schema_data: schema_data
      } = input

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^user_id,
        user_avatar_id: ^user_avatar_id,
        unique_identifier: @unique_identifier,
        key: key,
        filename: filename,
        e_tag: "etag",
        upload_id: nil,
        content_length: 11,
        content_type: "image/png",
        last_modified: ~U[2023-08-18 10:53:21Z],
        archived: false,
        archived_at: nil
      } = schema_data

      organization_id = Uppy.PathBuilder.encode_id(context.user.organization_id)

      permanent_key = "#{organization_id}-uploads/#{@unique_identifier}-example.txt"

      assert ^permanent_key = key

      # The filename extension should be replaced with the extension
      # detected by the file info phase.
      assert "example.png" = filename
    end

    test "rejects image with a width or height larger than 1024", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      # The phase `Uppy.Phases.HeadTemporaryObject` retrieves the metadata from
      # storage and adds it to the context for other phases in the pipeline.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      # The phase `Uppy.Phases.FileInfo` downloads the first 256 bytes of the object.
      file_header_chunk =
        File.cwd!()
        |> Path.join('/test_data/image_2000_2000.png')
        |> File.stream!([:raw], Uppy.Phases.FileInfo.default_end_byte())
        |> Enum.take(1)

      StorageSandbox.set_get_chunk_responses([
        {@bucket, fn -> {:ok, file_header_chunk} end}
      ])

      # The phase `Uppy.Phases.PutPermanentObjectCopy` puts a copy
      # of the temporary object in storage.
      StorageSandbox.set_put_object_copy_responses([
        {
          ~r|.*|,
          fn ->
            {:ok, %{
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

      # The phase `Uppy.Phases.PutPermanentObjectCopy` is removed from
      # the pipeline because if the image cannot be processed the phase
      # does not run.
      #
      # The phase `Uppy.Phases.PutImageProcessorResult` should not run
      # if any of the following are true:
      #
      # 1. The file is not an image
      # 2. The width or height is larger than 1_024
      # 3. The file is equal to or less than 5MB

      pipeline =
        [
          Uppy.Phases.ValidateObjectTemporaryPath,
          Uppy.Phases.HeadTemporaryObject,
          Uppy.Phases.FileHolder,
          Uppy.Phases.FileInfo,
          Uppy.Phases.PutImageProcessorResult,
          Uppy.Phases.ValidateObjectPermanentPath
        ]

      assert {:error, _} =
        Core.process_upload(
          pipeline,
          @bucket,
          @resource,
          @schema_source_tuple,
          schema_data
        )
    end
  end

  describe "&delete_object_if_upload_not_found/4" do
    test "returns ok when record not found and object is deleted", context do
      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: "key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, _} = Action.delete(schema_data)

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        Core.delete_object_if_upload_not_found(
          @bucket,
          @schema_source_tuple,
          schema_data.key
        )
    end

    test "returns error when record exists", context do
      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: "key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:error, error_message} =
        Core.delete_object_if_upload_not_found(
          @bucket,
          @schema_source_tuple,
          schema_data.key
        )

      assert %ErrorMessage{
        code: :forbidden,
        message: "cannot delete object due to existing record",
        details: %{
          params: %{key: "key"},
          schema: {Uppy.Support.PG.Objects.UserAvatarObject, "user_avatar_objects"},
          schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{}
        }
      } = error_message
    end
  end

  describe "&find_permanent_upload/2" do
    test "returns a record if :e_tag is not nil and :key is a temporary object key", context do
      user_id = PathBuilder.encode_id(context.user.id)

      permanent_key = "#{user_id}-uploads/user-avatars/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: permanent_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag"
        })

      assert {:ok, permanent_schema_data} =
        Core.find_permanent_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert permanent_schema_data.id === schema_data.id
    end

    test "can disable object key validation when option `:validate?` is set to false", context do
      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: "invalid-key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag"
        })

      assert {:ok, permanent_schema_data} =
        Core.find_permanent_upload(
          @schema_source_tuple,
          %{id: schema_data.id},
          validate?: false
        )

      assert permanent_schema_data.id === schema_data.id
    end
  end

  describe "&find_completed_upload/2" do
    test "returns record when field `:e_tag` is not nil and `:key` is a temporary object key", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag"
        })

      assert {:ok, actual_schema_data} =
        Core.find_completed_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert actual_schema_data.id === schema_data.id
    end
  end

  describe "&find_temporary_upload/2" do
    test "returns record when field `:e_tag` is nil and `:key` is a temporary object key", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, actual_schema_data} =
        Core.find_temporary_upload(
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert actual_schema_data.id === schema_data.id
    end

    test "can disable object key validation when option `:validate?` is set to false", context do
      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: "invalid-key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: "etag"
        })

      assert {:ok, actual_schema_data} =
        Core.find_temporary_upload(
          @schema_source_tuple,
          %{id: schema_data.id},
          validate?: false
        )

      assert actual_schema_data.id === schema_data.id
    end
  end

  describe "delete_upload/4" do
    test "deletes database record and schedules job to delete object", context do
      user_id = PathBuilder.encode_id(context.user.id)

      permanent_key = "#{user_id}-uploads/user-avatars/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: permanent_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, response} =
        Core.delete_upload(@bucket, @schema_source_tuple, %{id: schema_data.id})

      assert %{
        schema_data: delete_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = response

      schema_data_id = schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^expected_user_id,
        user_avatar_id: ^expected_user_avatar_id,
        unique_identifier: @unique_identifier,
        key: ^permanent_key,
        filename: "example.txt",
        e_tag: nil,
        upload_id: nil,
        content_length: nil,
        content_type: nil,
        last_modified: nil,
        archived: false,
        archived_at: nil
      } = delete_upload_schema_data

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: %{
          key: ^permanent_key,
          schema: "Uppy.Support.PG.Objects.UserAvatarObject",
          event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
          bucket: @bucket
        },
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      expected_delete_not_found_object_job_args = %{
        key: permanent_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^expected_delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
        args: expected_delete_not_found_object_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Schedulers.Oban.GarbageCollectorWorker,
          expected_delete_not_found_object_job_args
        )
    end
  end

  describe "&complete_upload/7" do
    test "updates the `:e_tag` and creates job to run the pipeline when the scheduler is enabled.", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      assert {:ok, response} =
        Core.complete_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          schema_data
        )

      assert %{
        metadata: metadata,
        schema_data: schema_data,
        jobs: %{
          process_upload: process_upload_job
        }
      } = response

      assert %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "etag",
        last_modified: ~U[2023-08-18 10:53:21Z]
      } = metadata

      assert %Uppy.Support.PG.Objects.UserAvatarObject{key: ^temporary_key} = schema_data

      process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockPipeline",
        resource: @resource,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects"
      }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
        args: ^process_upload_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = process_upload_job

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.PostProcessingWorker,
        args: process_upload_job_args,
        queue: :post_processing
      )

      schema_data_id = schema_data.id
      user_id = context.user.id
      user_avatar_id = context.user_avatar.id

      assert {:ok, response} =
        perform_job(
          Uppy.Schedulers.Oban.PostProcessingWorker,
          process_upload_job_args
        )

      assert {input, phases} = response

      assert  %Uppy.Pipeline.Input{
        schema_data: schema_data,
        schema: Uppy.Support.PG.Objects.UserAvatarObject,
        source: "user_avatar_objects",
        resource: "user-avatars",
        bucket: @bucket
      } = input

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        id: ^schema_data_id,
        user_id: ^user_id,
        user_avatar_id: ^user_avatar_id,
        unique_identifier: @unique_identifier,
        key: ^temporary_key,
        filename: "example.txt",
        e_tag: "etag",
        upload_id: nil,
        # metadata should be nil as file is not processed yet
        content_length: nil,
        content_type: nil,
        last_modified: nil,
        archived: false,
        archived_at: nil
      } = schema_data

      assert [Uppy.Phases.ValidateObjectTemporaryPath] = phases
    end

    test "updates :e_tag and creates a pipeline job when schema_data is provided and the scheduler is enabled.", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      assert {:ok, response} =
        Core.complete_upload(
          @bucket,
          @resource,
          MockPipeline,
          @schema_source_tuple,
          %{id: schema_data.id}
        )

      assert %{
        metadata: metadata,
        schema_data: schema_data,
        jobs: %{
          process_upload: process_upload_job
        }
      } = response

      assert %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "etag",
        last_modified: ~U[2023-08-18 10:53:21Z]
      } = metadata

      assert %Uppy.Support.PG.Objects.UserAvatarObject{key: ^temporary_key} = schema_data

      process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockPipeline",
        resource: @resource,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects"
      }

      assert %Oban.Job{
        state: "available",
        queue: "post_processing",
        worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
        args: ^process_upload_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = process_upload_job
    end
  end

  describe "&abort_upload/4" do
    test "deletes a upload record and creates job to garbage collect the object when the scheduler is enabled.", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      temporary_key = "temp/#{user_id}-user/example.txt"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: "example.txt",
          key: temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, response} = Core.abort_upload(@bucket, @schema_source_tuple, schema_data)

      assert %{
        schema_data: abort_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = response

      # should be the same database record
      assert abort_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{
          id: schema_data.id
        })

      # job should be schedule to delete the object incase it was
      # uploaded after deleting the record.
      delete_not_found_object_job_args = %{
        key: temporary_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
        args: delete_not_found_object_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Schedulers.Oban.GarbageCollectorWorker,
          delete_not_found_object_job_args
        )
    end
  end

  describe "&start_upload/5" do
    test "creates a record and schedules a job to abort the upload and garbage collect the object if the scheduler is enabled.", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      assert {:ok, response} =
        Core.start_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: "example.txt",
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          }
        )

      assert %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data,
        jobs: %{
          abort_upload: abort_upload_job
        }
      } = response

      expected_basename = "#{unique_identifier}-#{schema_data.filename}"

      assert ^expected_basename = basename

      expected_temporary_key = "temp/#{user_id}-user/#{schema_data.unique_identifier}-example.txt"

      assert ^expected_temporary_key = temporary_key

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^temporary_key,
        filename: @filename
      } = schema_data

      # the presigned upload must contain the keys `url` and `expires_at`
      assert String.contains?(presigned_upload.url, temporary_key)
      assert DateTime.compare(presigned_upload.expires_at, ~U[2024-07-24 02:51:32.453714Z]) === :eq

      abort_upload_job_args = %{
        id: schema_data.id,
        event: "uppy.abort_upload_worker.abort_upload",
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        source: "user_avatar_objects",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "abort_upload",
        worker: "Uppy.Schedulers.Oban.AbortUploadWorker",
        args: ^abort_upload_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = abort_upload_job

      # a job should be scheduled to abort and only abort if it's
      # a temporary object. If the upload is already processed
      # and permanently stored it must be deleted.
      abort_upload_job_args = %{
        event: "uppy.abort_upload_worker.abort_upload",
        bucket: @bucket,
        schema: inspect(@schema),
        id: schema_data.id
      }

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.AbortUploadWorker,
        args: abort_upload_job_args,
        queue: :abort_upload
      )

      assert {:ok, job_response} =
        perform_job(
          Uppy.Schedulers.Oban.AbortUploadWorker,
          abort_upload_job_args
        )

      assert %{
        schema_data: abort_upload_schema_data,
        jobs: %{
          delete_object_if_upload_not_found: delete_not_found_object_job
        }
      } = job_response

      # should be the same database record
      assert abort_upload_schema_data.id === schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
        PG.Objects.find_user_avatar_object(%{
          id: schema_data.id
        })

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      delete_not_found_object_job_args = %{
        key: temporary_key,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
        state: "available",
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
        args: ^delete_not_found_object_job_args,
        unique: %{
          timestamp: :inserted_at,
          keys: [],
          period: 300,
          fields: [:args, :queue, :worker],
          states: [:available, :scheduled, :executing]
        }
      } = delete_not_found_object_job

      # after performing the job another job should be schedule that can
      # garbage collect the object if it was uploaded after expiration.
      assert_enqueued(
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
        args: delete_not_found_object_job_args,
        queue: :garbage_collection
      )

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "etag",
          last_modified: ~U[2023-08-18 10:53:21Z]
        }} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert :ok =
        perform_job(
          Uppy.Schedulers.Oban.GarbageCollectorWorker,
          delete_not_found_object_job_args
        )
    end

    test "can set `:unique_identifier` field.", context do
      assert {:ok, response} =
        Core.start_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: "example.txt",
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id,
            unique_identifier: "custom_unique_identifier"
          }
        )

      assert %{
        unique_identifier: "custom_unique_identifier",
        schema_data: %{
          unique_identifier: "custom_unique_identifier"
        }
      } = response
    end

    test "creates a upload without job when the scheduler is disabled.", context do
      user_id = Uppy.PathBuilder.encode_id(context.user.id)

      assert {:ok, response} =
        Core.start_upload(
          @bucket,
          context.user.id,
          @schema_source_tuple,
          %{
            filename: "example.txt",
            user_avatar_id: context.user_avatar.id,
            user_id: context.user.id
          },
          scheduler_enabled?: false
        )

      assert %{
        unique_identifier: unique_identifier,
        basename: basename,
        key: temporary_key,
        presigned_upload: presigned_upload,
        schema_data: schema_data
      } = response

      # jobs should not be present
      refute response[:jobs]

      assert ^basename = "#{unique_identifier}-#{schema_data.filename}"

      expected_temporary_key = "temp/#{user_id}-user/#{schema_data.unique_identifier}-example.txt"

      assert ^expected_temporary_key = temporary_key

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
        unique_identifier: ^unique_identifier,
        key: ^temporary_key,
        filename: @filename
      } = schema_data

      # the presigned upload must contain the keys `url` and `expires_at`
      assert String.contains?(presigned_upload.url, expected_temporary_key)
      assert DateTime.compare(presigned_upload.expires_at, ~U[2024-07-24 02:51:32.453714Z]) === :eq
    end
  end
end
