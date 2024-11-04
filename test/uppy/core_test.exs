defmodule Uppy.CoreTest do
  use Uppy.DataCase, async: true

  alias Uppy.{
    Core,
    DBAction,
    Fixture,
    Schemas.FileInfoAbstract,
    StorageSandbox
  }

  @bucket "uppy-test"

  setup do
    StorageSandbox.set_presigned_url_responses([
      {
        @bucket,
        fn _http_method, object ->
          {
            :ok,
            %{
              url: "https://presigned.url/#{object}",
              expires_at: ~U[2024-07-24 01:00:00Z]
            }
          }
        end
      }
    ])
  end

  describe "&move_upload/6: " do
    test "moves object to permanent path" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          state: :available
        })

      schema_data_id = schema_data.id

      # Uppy.Phases.HeadSchemaObject

      sandbox_head_object_payload =
        %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          last_modified: ~U[2024-07-24 01:00:00Z]
        }

      # object must exist
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      # Uppy.Phases.PutPermanentObjectCopy

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

      # Uppy.Phases.FileInfo

      StorageSandbox.set_get_chunk_responses([
        {
          @bucket,
          fn ->
            {:ok, {0, "Hello world!"}}
          end
        }
      ])

      assert {:ok, %{
        done: done,
        resolution: resolution
      }} =
        Core.move_upload(
          @bucket,
          ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          nil,
          []
        )

      assert [
        Uppy.Phases.UpdateSchemaMetadata,
        Uppy.Phases.PutPermanentObjectCopy,
        # Uppy.Phases.PutPermanentImageObjectCopy,
        # Uppy.Phases.FileInfo,
        Uppy.Phases.HeadSchemaObject
      ] = done

      assert %Uppy.Resolution{
        state: :resolved,
        context: %{
          destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          metadata: ^sandbox_head_object_payload
        },
        bucket: "uppy-test",
        value: %Uppy.Schemas.FileInfoAbstract{
          state: :completed, # should be set to completed
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          # filename: nil,
          id: ^schema_data_id,
          key: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          last_modified: ~U[2024-07-24 01:00:00Z],
          # unique_identifier: nil,
          upload_id: nil,
          # assoc_id: nil,
          # user_id: nil
        }
      } = resolution
    end
  end

  describe "&queue_upload_for_deletion/4" do
    test "when scheduler is enabled, set state to cancelled | insert garbage collection job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :cancelled,
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: delete_object_and_upload_schema_data,
        jobs: %{
          delete_object_and_upload: delete_object_and_upload_job
        }
      }} =
        Core.queue_upload_for_deletion(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        state: :cancelled, # should be set to cancelled
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: nil,
        # assoc_id: nil,
        # user_id: nil
      } = delete_object_and_upload_schema_data

      assert %Oban.Job{
        args: %{
          bucket: "uppy-test",
          event: "uppy.delete_object_and_upload",
          query: _,
          id: ^schema_data_id
        },
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.ObanScheduler.GarbageCollectionWorker"
      } = delete_object_and_upload_job

      # record should exist
      assert {:ok, %{id: ^schema_data_id}} =
        DBAction.find(
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )
    end
  end

  describe "&delete_object_and_upload/4" do
    test "when state is :cancelled, delete object | delete record" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :cancelled,
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      sandbox_head_object_payload =
        %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          last_modified: ~U[2024-07-24 01:00:00Z]
        }

      # object must exist
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {
          @bucket,
          fn ->
            {
              :ok,
              %{
                body: "",
                headers: [
                  {"x-amz-id-2", "x_amz_id"},
                  {"x-amz-request-id", "x_amz_request_id"},
                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                  {"server", "AmazonS3"}
                ],
                state_code: 204
              }
            }
          end
        }
      ])

      assert {
        :ok,
        %{
          metadata: ^sandbox_head_object_payload,
          schema_data: delete_object_and_upload_schema_data
        }
      } =
        Core.delete_object_and_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: nil,
        # assoc_id: nil,
        # user_id: nil
      } = delete_object_and_upload_schema_data

      # record should be deleted
      assert {:error, %{code: :not_found}} =
        DBAction.find(
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )
    end

    test "when state is :cancelled and delete_object returns an error, do not delete record" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :cancelled,
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      sandbox_head_object_payload =
        %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          last_modified: ~U[2024-07-24 01:00:00Z]
        }

      # object must exist
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      StorageSandbox.set_delete_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      assert {:error, %{code: :not_found}} =
        Core.delete_object_and_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )

      # record should exist
      assert {:ok, %{id: ^schema_data_id}} =
        DBAction.find(
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )
    end

    test "when state is :cancelled and object not found, delete record" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :cancelled,
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      # object does not exist
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      assert {
        :ok,
        %{schema_data: delete_object_and_upload_schema_data}
      } =
        Core.delete_object_and_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: nil,
        # assoc_id: nil,
        # user_id: nil
      } = delete_object_and_upload_schema_data

      # record should be deleted
      assert {:error, %{code: :not_found}} =
        DBAction.find(
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          []
        )
    end
  end

  describe "complete_upload: " do
    test "when scheduler is enabled, updates state to available | insert job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      sandbox_head_object_response =
        %{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          last_modified: ~U[2024-07-24 01:00:00Z]
        }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn ->
          {:ok, sandbox_head_object_response}
        end}
      ])

      assert {:ok, %{
        metadata: ^sandbox_head_object_response,
        schema_data: complete_upload_schema_data,
        jobs: %{
          move_upload: move_upload_job
        }
      }} =
        Core.complete_upload(
          @bucket,
          ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          {"user_avatar_file_infos", FileInfoAbstract},
          schema_data,
          %{},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        state: :available, # state should be available
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag", # should be sandbox value
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg", # should be in temp path
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: nil,
        # assoc_id: nil,
        # user_id: nil
      } = complete_upload_schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.move_upload",
          bucket: "uppy-test",
          destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          id: ^schema_data_id,
          query: _,
          pipeline: ""
        },
        queue: "post_processing",
        worker: "Uppy.Schedulers.ObanScheduler.PostProcessingWorker"
      } = move_upload_job
    end
  end

  describe "abort_upload: " do
    test "when scheduler is enabled, updates state to cancelled | insert job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg"
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: schema_data,
        jobs: %{
          delete_object_and_upload: delete_object_and_upload_job
        }
      }} =
        Core.abort_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          schema_data,
          %{},
          []
        )

      # key and state should be set
      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        state: :cancelled, # should be cancelled
        # unique_identifier: nil,
        upload_id: nil
      } = schema_data

      assert %Oban.Job{
        args: %{
          bucket: "uppy-test",
          event: "uppy.delete_object_and_upload",
          query: _,
          id: ^schema_data_id
        },
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.ObanScheduler.GarbageCollectionWorker"
      } = delete_object_and_upload_job
    end
  end

  describe "start_upload: " do
    test "when scheduler is enabled, creates record with pending state | create presigned upload | insert job" do
      assert {:ok, %{
        presigned_upload: presigned_upload,
        schema_data: schema_data,
        jobs: %{
          abort_upload: abort_upload_job
        }
      }} =
        Core.start_upload(
          @bucket,
          "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          {"user_avatar_file_infos", FileInfoAbstract},
          %{},
          []
        )

      assert %{
        url: presigned_upload_url,
        expires_at: expires_at
      } = presigned_upload

      assert is_binary(presigned_upload_url)
      assert %DateTime{} = expires_at

      # key and state should be set
      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        state: :pending, # should be pending
        # unique_identifier: nil,
        upload_id: nil
      } = schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.abort_upload",
          bucket: "uppy-test",
          query: _,
          id: ^schema_data_id
        },
        queue: "expired_upload",
        worker: "Uppy.Schedulers.ObanScheduler.ExpiredUploadWorker"
      } = abort_upload_job
    end
  end

  ## Multipart API

  describe "find_parts: " do
    test "returns a list of parts from storage" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      sandbox_list_parts_payload =
        [
          %{
            size: 1,
            etag: "e_tag",
            part_number: 1
          }
        ]

      StorageSandbox.set_list_parts_responses([
        {@bucket, fn -> {:ok, sandbox_list_parts_payload} end}
      ])

      assert {:ok, %{
        parts: ^sandbox_list_parts_payload,
        schema_data: find_parts_schema_data
      }} =
        Core.find_parts(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          nil,
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        state: :pending,
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: "upload_id",
        # assoc_id: nil,
        # user_id: nil
      } = find_parts_schema_data
    end
  end

  describe "presigned_part: " do
    test "returns presigned part payload and expected record" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        presigned_part: %{
          url: "https://presigned.url/temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          expires_at: ~U[2024-07-24 01:00:00Z]
        },
        schema_data: presigned_part_schema_data
      }} =
        Core.presigned_part(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          1,
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        state: :pending,
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: "upload_id",
        # assoc_id: nil,
        # user_id: nil,
      } = presigned_part_schema_data
    end
  end

  describe "complete_multipart_upload: " do
    test "when scheduler is enabled, updates state to available | insert job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      sandbox_head_object_payload = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:ok, sandbox_head_object_payload} end}
      ])

      StorageSandbox.set_complete_multipart_upload_responses([
        {
          @bucket,
          fn object ->
            {:ok, %{
              location: "https://s3.com/#{object}",
              bucket: @bucket,
              key: object,
              e_tag: "e_tag"
            }}
          end
        }
      ])

      assert {:ok, %{
        metadata: ^sandbox_head_object_payload,
        schema_data: complete_multipart_upload_schema_data,
        jobs: %{
          move_upload: move_upload_job
        }
      }} =
        Core.complete_multipart_upload(
          @bucket,
          ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          [{1, "e_tag"}],
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        state: :available, # state should be available
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag", # should be sandbox value
        # filename: nil,
        id: ^schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg", # should be in temp path
        last_modified: nil,
        # unique_identifier: nil,
        upload_id: "upload_id", # should be set
        # assoc_id: nil,
        # user_id: nil
      } = complete_multipart_upload_schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.move_upload",
          bucket: "uppy-test",
          destination_object: ">DI_GRO<-organization/user-avatars/unique_identifier-image.jpeg",
          id: ^schema_data_id,
          pipeline: "",
          query: _,
        },
        queue: "post_processing",
        worker: "Uppy.Schedulers.ObanScheduler.PostProcessingWorker"
      } = move_upload_job
    end
  end

  describe "abort_multipart_upload: " do
    test "when scheduler is enabled, updates state to cancelled | insert job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_abort_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:ok, %{
              body: "",
              headers: [
                {"x-amz-id-2", "x_amz_id"},
                {"x-amz-request-id", "x_amz_request_id"},
                {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                {"server", "AmazonS3"}
              ],
              status_code: 204
            }}
          end
        }
      ])

      assert {:ok, %{
        schema_data: abort_upload_schema_data,
        metadata: abort_upload_metadata,
        jobs: %{
          delete_object_and_upload: delete_object_and_upload_job
        }
      }} =
        Core.abort_multipart_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          []
        )

      assert %{
        body: "",
        headers: [
          {"x-amz-id-2", "x_amz_id"},
          {"x-amz-request-id", "x_amz_request_id"},
          {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
          {"server", "AmazonS3"}
        ],
        status_code: 204
      } = abort_upload_metadata

      assert schema_data_id === abort_upload_schema_data.id

      assert %Oban.Job{
        args: %{
          event: "uppy.delete_object_and_upload",
          bucket: "uppy-test",
          id: ^schema_data_id,
          query: _
        },
        queue: "garbage_collection",
        worker: "Uppy.Schedulers.ObanScheduler.GarbageCollectionWorker"
      } = delete_object_and_upload_job
    end
  end

  describe "start_multipart_upload: " do
    test "creates record, creates presigned upload, and creates job" do
      StorageSandbox.set_initiate_multipart_upload_responses([
        {
          @bucket,
          fn object ->
            {:ok, %{
              key: object,
              bucket: @bucket,
              upload_id: "upload_id"
            }}
          end
        }
      ])

      assert {:ok, %{
        multipart_upload: multipart_upload,
        schema_data: schema_data,
        jobs: %{
          abort_multipart_upload: abort_multipart_upload_job
        }
      }} =
        Core.start_multipart_upload(
          @bucket,
          "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
          {"user_avatar_file_infos", FileInfoAbstract},
          %{},
          []
        )

      assert %{
        bucket: "uppy-test",
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        upload_id: "upload_id"
      } = multipart_upload

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        # filename: nil,
        id: schema_data_id,
        key: "temp/>DI_RESU<-user/unique_identifier-image.jpeg",
        last_modified: nil,
        state: :pending, # should be pending
        # unique_identifier: nil,
        upload_id: "upload_id" # upload_id should be set
      } = schema_data

      assert %Oban.Job{
        args: %{
          event: "uppy.abort_multipart_upload",
          bucket: "uppy-test",
          query: _,
          id: ^schema_data_id
        },
        queue: "expired_upload",
        worker: "Uppy.Schedulers.ObanScheduler.ExpiredUploadWorker"
      } = abort_multipart_upload_job
    end
  end
end
