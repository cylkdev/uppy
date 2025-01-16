defmodule Uppy.CoreTest do
  use Uppy.DataCase, async: true

  alias Uppy.{
    Core,
    Fixture,
    Schemas.FileInfoAbstract,
    StorageSandbox
  }

  @bucket "uppy-test"

  describe "move_to_destination " do
    test "can move existing object to location" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :completed,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              content_length: 11,
              content_type: "text/plain",
              e_tag: "e_tag",
              last_modified: ~U[2024-07-24 01:00:00Z]
            }}
         end}
      ])

      StorageSandbox.set_put_object_copy_responses([
        {
          ~r|.*|,
          fn ->
            {:ok,
             %{
               body: "body",
               headers: [
                 {"x-amz-id-2", "<amz_id>"},
                 {"x-amz-request-id", "<x_amz_request_id>"},
                 {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
                 {"x-amz-server-side-encryption", "<x_amz_server_side_encryption>"},
                 {"content-type", "<content_type>"},
                 {"server", "<server>"},
                 {"content-length", "<content_length>"}
               ],
               status_code: 200
             }}
          end
        }
      ])

      StorageSandbox.set_delete_object_responses([
        {
          ~r|.*|,
          fn ->
            {:ok,
            %{
              body: "",
              headers: [
                {"x-amz-id-2", "<x_amz_id_2>"},
                {"x-amz-request-id", "<x_amz_request_id>"},
                {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
                {"server", "<server>"}
              ],
              status_code: 204
            }}
          end
        }
      ])

      assert {:ok, result} =
               Core.move_to_destination(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 "permanent/destination_image.jpeg",
                 []
               )

      assert %{input: input, done: done} = result

      assert [Uppy.Phases.MoveToDestination] = done

      assert %{
        state: :resolved,
        bucket: @bucket,
        destination_object: "permanent/destination_image.jpeg",
        query: {"user_avatar_file_infos", Uppy.Schemas.FileInfoAbstract},
        schema_data: %Uppy.Schemas.FileInfoAbstract{
          status: :completed,
          content_length: 11,
          content_type: nil,
          e_tag: "e_tag",
          filename: "image.jpeg",
          key: "permanent/destination_image.jpeg",
          last_modified: %DateTime{},
          upload_id: nil
        }
      } = input
    end
  end

  describe "find_parts: " do
    test "returns parts" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_list_parts_responses([
        {@bucket,
         fn ->
           {:ok,
            [
              %{
                size: 1,
                etag: "e_tag",
                part_number: 1
              }
            ]}
         end}
      ])

      assert {:ok, result} =
               Core.find_parts(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 []
               )

      assert %{
               parts: parts,
               schema_data: schema_data
             } = result

      assert [
               %{
                 size: 1,
                 etag: "e_tag",
                 part_number: 1
               }
             ] = parts

      assert %Uppy.Schemas.FileInfoAbstract{
               status: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^schema_data_id,
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = schema_data
    end
  end

  describe "sign_part: " do
    test "can pre-sign part" do
      StorageSandbox.set_sign_part_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              url: "http://url/temp/image.jpeg",
              expires_at: ~U[2024-07-24 01:00:00Z]
            }}
         end}
      ])

      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      assert {:ok, result} =
               Core.sign_part(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 1,
                 []
               )

      assert %{
               sign_part: sign_part,
               schema_data: schema_data
             } = result

      assert %{
               url: "http://url/temp/image.jpeg",
               expires_at: ~U[2024-07-24 01:00:00Z]
             } = sign_part

      assert %Uppy.Schemas.FileInfoAbstract{
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^schema_data_id,
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = schema_data
    end
  end

  describe "complete_multipart_upload: " do
    test "can complete multipart upload" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              content_length: 11,
              content_type: "text/plain",
              e_tag: "e_tag",
              last_modified: ~U[2024-07-24 01:00:00Z]
            }}
         end}
      ])

      StorageSandbox.set_complete_multipart_upload_responses([
        {@bucket, fn -> {:ok, %{}} end}
      ])

      assert {:ok, result} =
               Core.complete_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 %{unique_identifier: "unique_id"},
                 [{1, "e_tag"}],
                 %{},
                 []
               )

      assert %{
               destination_object: destination_object,
               metadata: metadata,
               schema_data: schema_data
             } = result

      assert "-uploads/file_info_abstract/unique_id-image.jpeg" = destination_object

      assert %{
               content_length: 11,
               content_type: "text/plain",
               e_tag: "e_tag",
               last_modified: ~U[2024-07-24 01:00:00Z]
             } = metadata

      assert %Uppy.Schemas.FileInfoAbstract{
               status: :completed,
               content_length: nil,
               content_type: nil,
               e_tag: "e_tag",
               id: ^schema_data_id,
               unique_identifier: "unique_id",
               filename: "image.jpeg",
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = schema_data
    end
  end

  describe "abort_multipart_upload: " do
    test "can abort multipart upload" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg",
          upload_id: "upload_id"
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_abort_multipart_upload_responses([
        {
          @bucket,
          fn ->
            {:ok,
             %{
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

      assert {:ok, result} =
               Core.abort_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 %{},
                 []
               )

      assert %{schema_data: schema_data} = result

      assert %Uppy.Schemas.FileInfoAbstract{
               status: :aborted,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^schema_data_id,
               key: "temp/image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = schema_data
    end
  end

  describe "create_multipart_upload/6: " do
    test "can create multipart upload" do
      StorageSandbox.set_create_multipart_upload_responses([
        {
          @bucket,
          fn object ->
            {:ok,
             %{
               key: object,
               bucket: @bucket,
               upload_id: "upload_id"
             }}
          end
        }
      ])

      assert {:ok, result} =
               Core.create_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 "image.jpeg",
                 %{},
                 %{},
                 timestamp: "timestamp"
               )

      assert %{
               multipart_upload: multipart_upload,
               schema_data: schema_data
             } = result

      assert %{
               bucket: @bucket,
               key: "temp/-user/timestamp-image.jpeg",
               upload_id: "upload_id"
             } = multipart_upload

      assert %Uppy.Schemas.FileInfoAbstract{
               status: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               filename: "image.jpeg",
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = schema_data
    end
  end

  describe "complete_upload: " do
    test "can complete upload" do
      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg"
        })

      schema_data_id = schema_data.id

      StorageSandbox.set_head_object_responses([
        {@bucket,
         fn ->
           {:ok,
            %{
              content_length: 11,
              content_type: "text/plain",
              e_tag: "e_tag",
              last_modified: ~U[2024-07-24 01:00:00Z]
            }}
         end}
      ])

      assert {:ok, result} =
               Core.complete_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: schema_data_id},
                 %{},
                 %{},
                 []
               )

      assert %{
               metadata: metadata,
               schema_data: schema_data
             } = result

      assert %{
               content_length: 11,
               content_type: "text/plain",
               e_tag: "e_tag",
               last_modified: ~U[2024-07-24 01:00:00Z]
             } = metadata

      assert %Uppy.Schemas.FileInfoAbstract{
               status: :completed,
               content_length: nil,
               content_type: nil,
               e_tag: "e_tag",
               id: ^schema_data_id,
               key: "temp/image.jpeg",
               last_modified: nil,
               upload_id: nil
             } = schema_data
    end
  end

  describe "abort_upload/4: " do
    test "can abort upload" do
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      schema_data =
        Fixture.UserAvatarFileInfo.insert!(%{
          status: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg"
        })

      schema_data_id = schema_data.id

      assert {:ok, result} =
               Core.abort_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 schema_data,
                 %{},
                 []
               )

      assert %{
               schema_data: %Uppy.Schemas.FileInfoAbstract{
                 status: :aborted,
                 content_length: nil,
                 content_type: nil,
                 e_tag: nil,
                 id: ^schema_data_id,
                 key: "temp/image.jpeg",
                 last_modified: nil,
                 upload_id: nil
               }
             } = result
    end
  end

  describe "create_upload/6: " do
    test "can create upload" do
      StorageSandbox.set_pre_sign_responses([
        {
          @bucket,
          fn _http_method, object ->
            {
              :ok,
              %{
                url: "http://url/#{object}",
                expires_at: ~U[2024-07-24 01:00:00Z]
              }
            }
          end
        }
      ])

      assert {:ok, result} =
               Core.create_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 "image.jpeg",
                 %{},
                 %{},
                 timestamp: "timestamp"
               )

      assert %{
               signed_upload: %{
                 url: "http://url/temp/-user/timestamp-image.jpeg",
                 expires_at: %DateTime{}
               },
               schema_data: %Uppy.Schemas.FileInfoAbstract{
                 status: :pending,
                 content_length: nil,
                 content_type: nil,
                 e_tag: nil,
                 filename: "image.jpeg",
                 key: "temp/-user/timestamp-image.jpeg",
                 last_modified: nil,
                 upload_id: nil
               }
             } = result
    end
  end
end
