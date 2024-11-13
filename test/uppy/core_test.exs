defmodule Uppy.CoreTest do
  use Uppy.DataCase, async: true

  alias Uppy.{
    Core,
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

  ## Multipart API

  describe "find_parts: " do
    test "returns a list of parts from storage" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/image.jpeg",
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
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        id: ^schema_data_id,
        key: "temp/image.jpeg",
        last_modified: nil,
        upload_id: "upload_id"
      } = find_parts_schema_data
    end
  end

  describe "presigned_part: " do
    test "returns presigned part payload and expected record" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      assert {:ok, %{
        presigned_part: %{
          url: "https://presigned.url/temp/image.jpeg",
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
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        id: ^schema_data_id,
        key: "temp/image.jpeg",
        last_modified: nil,
        upload_id: "upload_id"
      } = presigned_part_schema_data
    end
  end

  describe "complete_multipart_upload: " do
    test "when scheduler is enabled, updates state to available | insert job" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/image.jpeg",
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
        schema_data: complete_multipart_upload_schema_data
      }} =
        Core.complete_multipart_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          [{1, "e_tag"}],
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag", # should be sandbox value
        id: ^schema_data_id,
        key: "temp/image.jpeg", # should be in temp path
        last_modified: nil,
        upload_id: "upload_id", # should be set
      } = complete_multipart_upload_schema_data
    end
  end

  describe "abort_multipart_upload: " do
    test "when archived is true, aborts storage upload | inserts job to delete object" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/image.jpeg",
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

      assert {:ok, %{schema_data: abort_upload_schema_data}} =
        Core.abort_multipart_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          []
        )

      assert schema_data_id === abort_upload_schema_data.id
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
        multipart_upload: %{
          bucket: @bucket,
          key: "temp/image.jpeg",
          upload_id: "upload_id"
        },
        schema_data: schema_data
      }} =
        Core.start_multipart_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{key: "temp/image.jpeg"},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: nil,
        id: _,
        key: "temp/image.jpeg",
        last_modified: nil,
        upload_id: "upload_id" # upload_id should be set
      } = schema_data
    end
  end

  describe "&process_upload/6: " do
    test "moves object to permanent path" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          key: "temp/image.jpeg",
          e_tag: "e_tag"
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
        {@bucket, fn -> {:ok, {0, "Hello world!"}} end}
      ])

      assert {:ok, %{
        done: done,
        resolution: resolution
      }} =
        Core.process_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          Uppy.Pipelines.PostProcessingPipeline,
          %{destination_object: "permanent/image.jpeg"},
          []
        )

      assert [
        Uppy.Phases.UpdateSchemaMetadata,
        Uppy.Phases.PutPermanentObjectCopy,
        Uppy.Phases.HeadSchemaObject
      ] = done

      assert %Uppy.Resolution{
        state: :resolved,
        context: %{
          destination_object: "permanent/image.jpeg",
          metadata: ^sandbox_head_object_payload
        },
        bucket: @bucket,
        value: %Uppy.Schemas.FileInfoAbstract{
          content_length: 11,
          content_type: "text/plain",
          e_tag: "e_tag",
          id: ^schema_data_id,
          key: "permanent/image.jpeg",
          last_modified: ~U[2024-07-24 01:00:00Z],
          upload_id: nil
        }
      } = resolution
    end
  end

  describe "confirm_upload: " do
    test "when object exists, updates state to :available and updates :e_tag" do
      schema_data = Fixture.UserAvatarFileInfo.insert!(%{key: "temp/image.jpeg"})

      schema_data_id = schema_data.id

      expected_metadata = %{
        content_length: 11,
        content_type: "text/plain",
        e_tag: "e_tag",
        last_modified: ~U[2024-07-24 01:00:00Z]
      }

      StorageSandbox.set_head_object_responses([
        {@bucket, fn ->
          {:ok, expected_metadata}
        end}
      ])

      assert {:ok, %{
        metadata: ^expected_metadata,
        schema_data: confirm_upload_schema_data
      }} =
        Core.confirm_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{id: schema_data_id},
          %{},
          []
        )

      assert %Uppy.Schemas.FileInfoAbstract{
        content_length: nil,
        content_type: nil,
        e_tag: "e_tag", # should be sandbox value
        id: ^schema_data_id,
        key: "temp/image.jpeg", # should be in temp path
        last_modified: nil,
        upload_id: nil,
      } = confirm_upload_schema_data
    end
  end

  describe "abort_upload: " do
    test "when object not found, update state to discarded" do
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      schema_data = Fixture.UserAvatarFileInfo.insert!(%{key: "temp/image.jpeg"})

      schema_data_id = schema_data.id

      assert {:ok, %{
        schema_data: %Uppy.Schemas.FileInfoAbstract{
          content_length: nil,
          content_type: nil,
          e_tag: nil,
          id: ^schema_data_id,
          key: "temp/image.jpeg",
          last_modified: nil,
          upload_id: nil
        }
      }} =
        Core.abort_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          schema_data,
          %{},
          []
        )
    end
  end

  describe "start_upload: " do
    test "when params valid, returns result with :pending state and presigned url for the key" do
      assert {:ok, %{
        presigned_upload: %{
          url: "https://presigned.url/temp/image.jpeg",
          expires_at: %DateTime{}
        },
        schema_data: %Uppy.Schemas.FileInfoAbstract{
          content_length: nil,
          content_type: nil,
          e_tag: nil,
          id: _id,
          key: "temp/image.jpeg",
          last_modified: nil,
          upload_id: nil
        }
      }} =
        Core.start_upload(
          @bucket,
          {"user_avatar_file_infos", FileInfoAbstract},
          %{key: "temp/image.jpeg"},
          []
        )
    end
  end
end
