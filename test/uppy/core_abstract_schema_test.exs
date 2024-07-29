defmodule Uppy.CoreAbstractSchemaTest do
  use Uppy.Support.DataCase, async: true

  alias Uppy.{
    Action,
    Core,
    TemporaryObjectKey
  }

  alias Uppy.Support.{
    Factory,
    PG,
    StorageSandbox
  }

  @schema Uppy.Support.PG.Objects.UserAvatarObject
  @source "user_avatar_objects"
  @schema_source_tuple {@schema, @source}

  @resource_name "user-avatars"

  @bucket "test_bucket"
  @filename "test_filename.txt"
  @unique_identifier "test_unique_identifier"
  @upload_id "test_upload_id"

  @expires_at ~U[2024-07-24 02:51:32.453714Z]
  @content_length 11
  @content_type "text/plain"
  @e_tag "etag"
  @size 1
  @last_modified ~U[2023-08-18 10:53:21Z]
  @storage_object_metadata %{
    content_length: @content_length,
    content_type: @content_type,
    e_tag: @e_tag,
    last_modified: @last_modified
  }

  defmodule MockTestPipeline do
    def pipeline(_options) do
      [Uppy.Phases.TemporaryObjectKeyValidate]
    end
  end

  setup do
    organization = FactoryEx.insert!(Factory.Accounts.Organization)
    user = FactoryEx.insert!(Factory.Accounts.User, %{organization_id: organization.id})
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})

    user_avatar =
      FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

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
            expires_at: @expires_at
          }}
       end}
    ])
  end

  describe "&find_permanent_multipart_upload/2" do
    test "returns record when `:e_tag` is not nil and `:key` is a permanent object key",
         context do
      expected_temporary_key =
        "#{String.reverse("#{context.user.id}")}-uploads/user-avatars/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag,
          upload_id: @upload_id
        })

      assert {:ok, actual_schema_data} =
               Core.find_permanent_multipart_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "&find_completed_multipart_upload/2" do
    test "returns record when `:e_tag` is not nil",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag,
          upload_id: @upload_id
        })

      assert {:ok, actual_schema_data} =
               Core.find_completed_multipart_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "&find_temporary_multipart_upload/2" do
    test "returns record when `:e_tag` is not nil and `:key` is a temporary object key",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      assert {:ok, actual_schema_data} =
               Core.find_temporary_multipart_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "&find_parts/5" do
    test "returns the parts for a multipart upload", context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      expected_schema_data_id = expected_schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      StorageSandbox.set_list_parts_responses([
        {@bucket,
         fn ->
           {:ok,
            [
              %{
                size: @size,
                etag: @e_tag,
                part_number: 1
              }
            ]}
         end}
      ])

      assert {:ok,
              %{
                parts: [
                  %{
                    size: @size,
                    etag: @e_tag,
                    part_number: 1
                  }
                ],
                schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
                  id: ^expected_schema_data_id,
                  user_id: ^expected_user_id,
                  user_avatar_id: ^expected_user_avatar_id,
                  unique_identifier: @unique_identifier,
                  key: ^expected_temporary_key,
                  filename: @filename,
                  e_tag: nil,
                  upload_id: @upload_id,
                  content_length: nil,
                  content_type: nil,
                  last_modified: nil,
                  archived: false,
                  archived_at: nil
                }
              }} =
               Core.find_parts(
                 @bucket,
                 @schema,
                 %{id: expected_schema_data.id}
               )
    end
  end

  describe "&presigned_part/5" do
    test "returns presigned url payload and schema data", context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      expected_presigned_url = "https://url.com/#{expected_temporary_key}"

      expected_schema_data_id = expected_schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert {:ok,
              %{
                presigned_part: %{
                  url: ^expected_presigned_url,
                  expires_at: @expires_at
                },
                schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
                  id: ^expected_schema_data_id,
                  user_id: ^expected_user_id,
                  user_avatar_id: ^expected_user_avatar_id,
                  unique_identifier: @unique_identifier,
                  key: ^expected_temporary_key,
                  filename: @filename,
                  e_tag: nil,
                  upload_id: @upload_id,
                  content_length: nil,
                  content_type: nil,
                  last_modified: nil,
                  archived: false,
                  archived_at: nil
                }
              }} =
               Core.presigned_part(
                 @bucket,
                 @schema,
                 %{id: expected_schema_data.id},
                 1
               )
    end
  end

  describe "&complete_multipart_upload/7" do
    test "updates the `:e_tag and creates pipeline job when given `schema_data` as an argument and the scheduler is enabled",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              location: "https://s3.com/#{expected_temporary_key}",
              bucket: @bucket,
              key: expected_temporary_key,
              e_tag: @e_tag
            }}
         end}
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok,
              %{
                metadata: @storage_object_metadata,
                schema_data: expected_schema_data,
                jobs: %{process_upload: process_upload_job}
              }} =
               Core.complete_multipart_upload(
                 @bucket,
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 expected_schema_data,
                 %{},
                 [{1, @e_tag}]
               )

      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               key: ^expected_temporary_key,
               e_tag: @e_tag
             } = expected_schema_data

      expected_process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: expected_schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockTestPipeline",
        resource_name: @resource_name,
        schema: inspect(@schema),
        source: @source
      }

      assert %Oban.Job{
               state: "available",
               queue: "post_processing",
               worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
               args: ^expected_process_upload_job_args,
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
        args: expected_process_upload_job_args,
        queue: :post_processing
      )

      expected_schema_data_id = expected_schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert {
               :ok,
               {
                 %Uppy.Pipeline.Input{
                   schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
                     id: ^expected_schema_data_id,
                     user_id: ^expected_user_id,
                     user_avatar_id: ^expected_user_avatar_id,
                     unique_identifier: @unique_identifier,
                     key: ^expected_temporary_key,
                     filename: @filename,
                     e_tag: @e_tag,
                     upload_id: @upload_id,
                     # metadata should be nil as file is not processed yet
                     content_length: nil,
                     content_type: nil,
                     last_modified: nil,
                     archived: false,
                     archived_at: nil
                   },
                   schema: Uppy.Support.PG.Objects.UserAvatarObject,
                   source: @source,
                   resource_name: "user-avatars",
                   bucket: @bucket
                 },
                 [Uppy.Phases.TemporaryObjectKeyValidate]
               }
             } =
               perform_job(
                 Uppy.Schedulers.Oban.PostProcessingWorker,
                 expected_process_upload_job_args
               )
    end

    test "updates the `:e_tag and creates pipeline job when given a `schema` module and `params` map as an argument and the scheduler is enabled",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              location: "https://s3.com/#{expected_temporary_key}",
              bucket: @bucket,
              key: expected_temporary_key,
              e_tag: @e_tag
            }}
         end}
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok,
              %{
                metadata: @storage_object_metadata,
                schema_data: expected_schema_data,
                jobs: %{process_upload: process_upload_job}
              }} =
               Core.complete_multipart_upload(
                 @bucket,
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 %{id: expected_schema_data.id},
                 %{},
                 [{1, @e_tag}]
               )

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               key: ^expected_temporary_key,
               e_tag: @e_tag
             } = expected_schema_data

      expected_process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: expected_schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockTestPipeline",
        resource_name: @resource_name,
        schema: inspect(@schema),
        source: @source
      }

      assert %Oban.Job{
               state: "available",
               queue: "post_processing",
               worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
               args: ^expected_process_upload_job_args,
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
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok,
              %{
                metadata: @storage_object_metadata,
                schema_data: expected_schema_data,
                jobs: %{process_upload: process_upload_job}
              }} =
               Core.complete_multipart_upload(
                 @bucket,
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 %{id: expected_schema_data.id},
                 %{},
                 [{1, @e_tag}]
               )

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               key: ^expected_temporary_key,
               e_tag: @e_tag
             } = expected_schema_data

      expected_process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: expected_schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockTestPipeline",
        resource_name: @resource_name,
        schema: inspect(@schema),
        source: @source
      }

      assert %Oban.Job{
               state: "available",
               queue: "post_processing",
               worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
               args: ^expected_process_upload_job_args,
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
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
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
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 %{id: expected_schema_data.id},
                 %{},
                 [{1, @e_tag}]
               )
    end
  end

  describe "&abort_multipart_upload/4" do
    test "deletes record and creates job to garbage collect the object when the scheduler is enabled.",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
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

      assert {:ok,
              %{
                schema_data: abort_multipart_upload_schema_data,
                jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
              }} =
               Core.abort_multipart_upload(@bucket, @schema_source_tuple, expected_schema_data)

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === expected_schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
               PG.Objects.find_user_avatar_object(%{id: expected_schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
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
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
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
                 Uppy.Schedulers.Oban.GarbageCollectorWorker,
                 expected_delete_object_if_upload_not_found_job_args
               )
    end

    test "can abort an already aborted upload, delete the record and create a job to garbage collect the object when the scheduler is enabled.",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_abort_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:error, %{code: :not_found}}
          end
        }
      ])

      assert {:ok,
              %{
                schema_data: abort_multipart_upload_schema_data,
                jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
              }} =
               Core.abort_multipart_upload(@bucket, @schema_source_tuple, expected_schema_data)

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === expected_schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
               PG.Objects.find_user_avatar_object(%{id: expected_schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
               args: ^expected_delete_object_if_upload_not_found_job_args,
               unique: %{
                 timestamp: :inserted_at,
                 keys: [],
                 period: 300,
                 fields: [:args, :queue, :worker],
                 states: [:available, :scheduled, :executing]
               }
             } = delete_object_if_upload_not_found_job
    end

    test "returns unhandled error",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          upload_id: @upload_id
        })

      StorageSandbox.set_abort_multipart_upload_responses([
        {@bucket, fn -> {:error, %{code: :internal_server_error}} end}
      ])

      assert {:error, %{code: :internal_server_error}} =
               Core.abort_multipart_upload(@bucket, @schema_source_tuple, expected_schema_data)
    end
  end

  describe "&start_multipart_upload/5" do
    test "It initializes a multipart upload, creates a database record, and schedules its deletion after expiration. It also schedules a job to garbage collect the object after the record is deleted.",
         context do
      StorageSandbox.set_initiate_multipart_upload_responses([
        {@bucket,
         fn object ->
           {:ok,
            %{
              key: object,
              bucket: @bucket,
              upload_id: @upload_id
            }}
         end}
      ])

      assert {:ok,
              %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: temporary_key,
                multipart_upload: multipart_upload,
                schema_data: expected_schema_data,
                jobs: %{abort_multipart_upload: abort_multipart_upload_job}
              }} =
               Core.start_multipart_upload(
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

      assert TemporaryObjectKey.validate(temporary_key)

      assert ^basename = "#{unique_identifier}-#{expected_schema_data.filename}"

      assert %{
               key: ^expected_temporary_key,
               bucket: @bucket,
               upload_id: @upload_id
             } = multipart_upload

      # upload id should be stored
      assert expected_schema_data.upload_id === @upload_id

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               unique_identifier: ^unique_identifier,
               key: ^expected_temporary_key,
               filename: @filename
             } = expected_schema_data

      expected_abort_multipart_upload_job_args = %{
        id: expected_schema_data.id,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.abort_upload_worker.abort_multipart_upload",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "abort_upload",
               worker: "Uppy.Schedulers.Oban.AbortUploadWorker",
               args: ^expected_abort_multipart_upload_job_args,
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

      expected_abort_multipart_upload_job_args = %{
        event: "uppy.abort_upload_worker.abort_multipart_upload",
        bucket: @bucket,
        schema: inspect(@schema),
        source: @source,
        id: expected_schema_data.id
      }

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.AbortUploadWorker,
        args: expected_abort_multipart_upload_job_args,
        queue: :abort_upload
      )

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

      assert {:ok,
              %{
                schema_data: abort_multipart_upload_schema_data,
                jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
              }} =
               perform_job(
                 Uppy.Schedulers.Oban.AbortUploadWorker,
                 expected_abort_multipart_upload_job_args
               )

      # should be the same database record
      assert abort_multipart_upload_schema_data.id === expected_schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
               PG.Objects.find_user_avatar_object(%{id: expected_schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
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
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
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
                 Uppy.Schedulers.Oban.GarbageCollectorWorker,
                 expected_delete_object_if_upload_not_found_job_args
               )
    end

    test "creates a record only when the scheduler is disabled.", context do
      StorageSandbox.set_initiate_multipart_upload_responses([
        {@bucket,
         fn object ->
           {:ok,
            %{
              key: object,
              bucket: @bucket,
              upload_id: @upload_id
            }}
         end}
      ])

      assert {:ok,
              %{
                unique_identifier: expected_unique_identifier,
                basename: expected_basename,
                key: expected_temporary_key,
                multipart_upload: expected_multipart_upload,
                schema_data: expected_schema_data
              } = expected_response} =
               Core.start_multipart_upload(
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
      refute expected_response[:jobs]

      # key should be in the temporary path
      assert ^expected_temporary_key =
               "temp/#{String.reverse("#{context.user.id}")}-user/#{expected_basename}"

      assert TemporaryObjectKey.validate(expected_temporary_key)

      assert ^expected_basename = "#{expected_unique_identifier}-#{expected_schema_data.filename}"

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               unique_identifier: ^expected_unique_identifier,
               key: ^expected_temporary_key,
               filename: @filename
             } = expected_schema_data

      assert %{
               key: ^expected_temporary_key,
               bucket: @bucket,
               upload_id: @upload_id
             } = expected_multipart_upload
    end
  end

  describe "&process_upload/6" do
    test "returns input`", context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      pipeline = [
        Uppy.Phases.TemporaryObjectKeyValidate
      ]

      expected_schema_data_id = expected_schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert {:ok,
              {
                %Uppy.Pipeline.Input{
                  bucket: @bucket,
                  resource_name: @resource_name,
                  schema: @schema,
                  source: @source,
                  schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
                    id: ^expected_schema_data_id,
                    user_id: ^expected_user_id,
                    user_avatar_id: ^expected_user_avatar_id,
                    unique_identifier: @unique_identifier,
                    key: ^expected_temporary_key,
                    filename: @filename,
                    e_tag: nil,
                    upload_id: nil,
                    content_length: nil,
                    content_type: nil,
                    last_modified: nil,
                    archived: false,
                    archived_at: nil
                  }
                },
                [Uppy.Phases.TemporaryObjectKeyValidate]
              }} =
               Core.process_upload(
                 pipeline,
                 @bucket,
                 @resource_name,
                 @schema_source_tuple,
                 expected_schema_data
               )
    end
  end

  describe "&delete_object_if_upload_not_found/4" do
    test "returns ok when record not found and object is deleted", context do
      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: "key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, _} = Action.delete(expected_schema_data)

      # storage head_object must return an ok response to proceed with deleting.
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert :ok =
               Core.delete_object_if_upload_not_found(@bucket, @schema, expected_schema_data.key)
    end

    test "returns error when record exists", context do
      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: "key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:error,
              %ErrorMessage{
                code: :forbidden,
                message: "deleting the object for an existing record is not allowed",
                details: %{
                  params: %{key: "key"},
                  schema: Uppy.Support.PG.Objects.UserAvatarObject,
                  schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{}
                }
              }} =
               Core.delete_object_if_upload_not_found(@bucket, @schema, expected_schema_data.key)
    end
  end

  describe "&find_permanent_upload/2" do
    test "returns record when field `:e_tag` is not nil and `:key` is a temporary object key",
         context do
      expected_temporary_key =
        "#{String.reverse("#{context.user.id}")}-uploads/user-avatars/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag
        })

      assert {:ok, actual_schema_data} =
               Core.find_permanent_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end

    test "can disable object key validation when option `:validate?` is set to false",
         context do
      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: "invalid-key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag
        })

      assert {:ok, actual_schema_data} =
               Core.find_permanent_upload(@schema, %{id: expected_schema_data.id},
                 validate?: false
               )

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "&find_completed_upload/2" do
    test "returns record when field `:e_tag` is not nil and `:key` is a temporary object key",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag
        })

      assert {:ok, actual_schema_data} =
               Core.find_completed_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "&find_temporary_upload/2" do
    test "returns record when field `:e_tag` is nil and `:key` is a temporary object key",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok, actual_schema_data} =
               Core.find_temporary_upload(@schema, %{id: expected_schema_data.id})

      assert actual_schema_data.id === expected_schema_data.id
    end

    test "can disable object key validation when option `:validate?` is set to false",
         context do
      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: "invalid-key",
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id,
          e_tag: @e_tag
        })

      assert {:ok, actual_schema_data} =
               Core.find_temporary_upload(@schema, %{id: expected_schema_data.id},
                 validate?: false
               )

      assert actual_schema_data.id === expected_schema_data.id
    end
  end

  describe "delete_upload/4" do
    test "deletes database record and schedules job to delete object", context do
      expected_permanent_key =
        "#{String.reverse("#{context.user.id}")}-uploads/user-avatars/#{@filename}"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_permanent_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok,
              %{
                schema_data: delete_upload_schema_data,
                jobs: %{
                  delete_object_if_upload_not_found: delete_object_if_upload_not_found_job
                }
              }} =
               Core.delete_upload(
                 @bucket,
                 @schema_source_tuple,
                 %{id: schema_data.id}
               )

      schema_data_id = schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               id: ^schema_data_id,
               user_id: ^expected_user_id,
               user_avatar_id: ^expected_user_avatar_id,
               unique_identifier: @unique_identifier,
               key: ^expected_permanent_key,
               filename: @filename,
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
                 key: ^expected_permanent_key,
                 schema: "Uppy.Support.PG.Objects.UserAvatarObject",
                 event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
                 bucket: @bucket
               },
               meta: %{},
               tags: [],
               errors: [],
               attempt: 0,
               attempted_by: nil,
               max_attempts: 20,
               priority: nil,
               attempted_at: nil,
               cancelled_at: nil,
               completed_at: nil,
               discarded_at: nil,
               inserted_at: nil,
               scheduled_at: nil,
               conf: nil,
               conflict?: false,
               replace: nil,
               unique: %{
                 timestamp: :inserted_at,
                 keys: [],
                 period: 300,
                 fields: [:args, :queue, :worker],
                 states: [:available, :scheduled, :executing]
               },
               unsaved_error: nil
             } = delete_object_if_upload_not_found_job

      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_permanent_key,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
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
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
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
                 Uppy.Schedulers.Oban.GarbageCollectorWorker,
                 expected_delete_object_if_upload_not_found_job_args
               )
    end
  end

  describe "&complete_upload/7" do
    test "updates the `:e_tag` and creates job to run the pipeline when the scheduler is enabled.",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok,
              %{
                metadata: @storage_object_metadata,
                schema_data: expected_schema_data,
                jobs: %{process_upload: process_upload_job}
              }} =
               Core.complete_upload(
                 @bucket,
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 expected_schema_data
               )

      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               key: ^expected_temporary_key
             } = expected_schema_data

      expected_process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: expected_schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockTestPipeline",
        resource_name: @resource_name,
        schema: inspect(@schema),
        source: @source
      }

      assert %Oban.Job{
               state: "available",
               queue: "post_processing",
               worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
               args: ^expected_process_upload_job_args,
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
        args: expected_process_upload_job_args,
        queue: :post_processing
      )

      expected_schema_data_id = expected_schema_data.id
      expected_user_id = context.user.id
      expected_user_avatar_id = context.user_avatar.id

      assert {
               :ok,
               {
                 %Uppy.Pipeline.Input{
                   schema_data: %Uppy.Support.PG.Objects.UserAvatarObject{
                     id: ^expected_schema_data_id,
                     user_id: ^expected_user_id,
                     user_avatar_id: ^expected_user_avatar_id,
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
                   schema: Uppy.Support.PG.Objects.UserAvatarObject,
                   source: @source,
                   resource_name: "user-avatars",
                   bucket: @bucket
                 },
                 [Uppy.Phases.TemporaryObjectKeyValidate]
               }
             } =
               perform_job(
                 Uppy.Schedulers.Oban.PostProcessingWorker,
                 expected_process_upload_job_args
               )
    end

    test "updates the `:e_tag and creates pipeline job when given `schema_data` as an argument and the scheduler is enabled",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      expected_schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, @storage_object_metadata} end}
      ])

      assert {:ok,
              %{
                metadata: @storage_object_metadata,
                schema_data: expected_schema_data,
                jobs: %{process_upload: process_upload_job}
              }} =
               Core.complete_upload(
                 @bucket,
                 @resource_name,
                 MockTestPipeline,
                 @schema_source_tuple,
                 %{id: expected_schema_data.id}
               )

      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               key: ^expected_temporary_key
             } = expected_schema_data

      expected_process_upload_job_args = %{
        bucket: @bucket,
        event: "uppy.post_processing_worker.process_upload",
        id: expected_schema_data.id,
        pipeline: "Uppy.CoreAbstractSchemaTest.MockTestPipeline",
        resource_name: @resource_name,
        schema: inspect(@schema),
        source: @source
      }

      assert %Oban.Job{
               state: "available",
               queue: "post_processing",
               worker: "Uppy.Schedulers.Oban.PostProcessingWorker",
               args: ^expected_process_upload_job_args,
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
    test "deletes a upload record and creates job to garbage collect the object when the scheduler is enabled.",
         context do
      expected_temporary_key = "temp/#{String.reverse("#{context.user.id}")}-user/#{@filename}"

      schema_data =
        FactoryEx.insert!(Factory.Objects.UserAvatarObject, %{
          unique_identifier: @unique_identifier,
          filename: @filename,
          key: expected_temporary_key,
          user_avatar_id: context.user_avatar.id,
          user_id: context.user.id
        })

      assert {:ok,
              %{
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
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
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
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
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
                 Uppy.Schedulers.Oban.GarbageCollectorWorker,
                 expected_delete_object_if_upload_not_found_job_args
               )
    end
  end

  describe "&start_upload/5" do
    test "creates a upload and a job to abort the upload and garbage collect the object when the scheduler is enabled.",
         context do
      assert {:ok,
              %{
                unique_identifier: expected_unique_identifier,
                basename: expected_basename,
                key: expected_temporary_key,
                presigned_upload: expected_presigned_upload,
                schema_data: expected_schema_data,
                jobs: %{abort_upload: expected_abort_upload_job}
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
      assert ^expected_temporary_key =
               "temp/#{String.reverse("#{context.user.id}")}-user/#{expected_basename}"

      assert TemporaryObjectKey.validate(expected_temporary_key)

      assert ^expected_basename = "#{expected_unique_identifier}-#{expected_schema_data.filename}"

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               unique_identifier: ^expected_unique_identifier,
               key: ^expected_temporary_key,
               filename: @filename
             } = expected_schema_data

      # the presigned upload must contain the keys `url` and `expires_at`
      assert String.contains?(expected_presigned_upload.url, expected_temporary_key)
      assert DateTime.compare(expected_presigned_upload.expires_at, @expires_at) === :eq

      expected_abort_upload_job_args = %{
        id: expected_schema_data.id,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.abort_upload_worker.abort_upload",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "abort_upload",
               worker: "Uppy.Schedulers.Oban.AbortUploadWorker",
               args: ^expected_abort_upload_job_args,
               unique: %{
                 timestamp: :inserted_at,
                 keys: [],
                 period: 300,
                 fields: [:args, :queue, :worker],
                 states: [:available, :scheduled, :executing]
               }
             } = expected_abort_upload_job

      # a job should be scheduled to abort and only abort if it's a temporary object.
      # If the upload is already processed and permanently stored it must be deleted.

      expected_abort_upload_job_args = %{
        event: "uppy.abort_upload_worker.abort_upload",
        bucket: @bucket,
        schema: inspect(@schema),
        source: @source,
        id: expected_schema_data.id
      }

      assert_enqueued(
        worker: Uppy.Schedulers.Oban.AbortUploadWorker,
        args: expected_abort_upload_job_args,
        queue: :abort_upload
      )

      assert {:ok,
              %{
                schema_data: abort_upload_schema_data,
                jobs: %{delete_object_if_upload_not_found: delete_object_if_upload_not_found_job}
              }} =
               perform_job(
                 Uppy.Schedulers.Oban.AbortUploadWorker,
                 expected_abort_upload_job_args
               )

      # should be the same database record
      assert abort_upload_schema_data.id === expected_schema_data.id

      # The record should not exist.
      assert {:error, %{code: :not_found}} =
               PG.Objects.find_user_avatar_object(%{id: expected_schema_data.id})

      # job should be schedule to delete the object incase it was uploaded after deleting the record.
      expected_delete_object_if_upload_not_found_job_args = %{
        key: expected_temporary_key,
        source: @source,
        schema: "Uppy.Support.PG.Objects.UserAvatarObject",
        event: "uppy.garbage_collector_worker.delete_object_if_upload_not_found",
        bucket: @bucket
      }

      assert %Oban.Job{
               state: "available",
               queue: "garbage_collection",
               worker: "Uppy.Schedulers.Oban.GarbageCollectorWorker",
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
        worker: Uppy.Schedulers.Oban.GarbageCollectorWorker,
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
                 Uppy.Schedulers.Oban.GarbageCollectorWorker,
                 expected_delete_object_if_upload_not_found_job_args
               )
    end

    test "can set `:unique_identifier` field.", context do
      assert {:ok,
              %{
                unique_identifier: "custom_unique_identifier",
                schema_data: %{
                  unique_identifier: "custom_unique_identifier"
                }
              }} =
               Core.start_upload(
                 @bucket,
                 context.user.id,
                 @schema_source_tuple,
                 %{
                   filename: @filename,
                   user_avatar_id: context.user_avatar.id,
                   user_id: context.user.id,
                   unique_identifier: "custom_unique_identifier"
                 }
               )
    end

    test "creates a upload without job when the scheduler is disabled.", context do
      assert {:ok,
              %{
                unique_identifier: expected_unique_identifier,
                basename: expected_basename,
                key: expected_temporary_key,
                presigned_upload: expected_presigned_upload,
                schema_data: expected_schema_data
              } = expected_response} =
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
      refute expected_response[:jobs]

      # key should be in the temporary path
      assert ^expected_temporary_key =
               "temp/#{String.reverse("#{context.user.id}")}-user/#{expected_basename}"

      assert TemporaryObjectKey.validate(expected_temporary_key)

      assert ^expected_basename = "#{expected_unique_identifier}-#{expected_schema_data.filename}"

      # the expected fields are set on the schema data
      assert %Uppy.Support.PG.Objects.UserAvatarObject{
               unique_identifier: ^expected_unique_identifier,
               key: ^expected_temporary_key,
               filename: @filename
             } = expected_schema_data

      # the presigned upload must contain the keys `url` and `expires_at`
      assert String.contains?(expected_presigned_upload.url, expected_temporary_key)
      assert DateTime.compare(expected_presigned_upload.expires_at, @expires_at) === :eq
    end
  end
end
