defmodule Uppy.CoreTest do
  use Uppy.Support.DataCase, async: true

  alias Uppy.Core

  alias Uppy.Support.{
    Fixture,
    Schemas.FileInfoAbstract,
    StorageSandbox
  }

  @bucket "uppy-test"

  describe "move_to_destination " do
    test "can move existing object to location" do
      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :completed,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg"
        })

      struct_id = struct.id

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

      assert {:ok, payload} =
               Core.move_to_destination(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 "permanent/destination_image.jpeg",
                 []
               )

      assert %{resolution: resolution, done: done} = payload

      assert [Uppy.Phases.MoveToDestination] = done

      assert %{
               state: :resolved,
               bucket: @bucket,
               query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
               arguments: %{
                 destination_object: "permanent/destination_image.jpeg"
               },
               value: %{
                 state: :ready,
                 content_length: 11,
                 content_type: nil,
                 e_tag: "e_tag",
                 filename: "image.jpeg",
                 key: "permanent/destination_image.jpeg",
                 last_modified: %DateTime{},
                 upload_id: nil
               }
             } = resolution
    end
  end

  describe "find_parts: " do
    test "returns parts" do
      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      struct_id = struct.id

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

      assert {:ok, payload} =
               Core.find_parts(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 []
               )

      assert %{
               parts: parts,
               data: struct
             } = payload

      assert [
               %{
                 size: 1,
                 etag: "e_tag",
                 part_number: 1
               }
             ] = parts

      assert %{
               state: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^struct_id,
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = struct
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

      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      struct_id = struct.id

      assert {:ok, payload} =
               Core.sign_part(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 1,
                 []
               )

      assert %{
               signed_part: signed_part,
               data: struct
             } = payload

      assert %{
               url: "http://url/temp/image.jpeg",
               expires_at: ~U[2024-07-24 01:00:00Z]
             } = signed_part

      assert %{
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^struct_id,
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = struct
    end
  end

  describe "complete_multipart_upload: " do
    test "can complete multipart upload" do
      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/-user/timestamp-image.jpeg",
          upload_id: "upload_id"
        })

      struct_id = struct.id

      StorageSandbox.set_complete_multipart_upload_responses([
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

      assert {:ok, payload} =
               Core.complete_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 %{unique_identifier: "unique_id"},
                 [{1, "e_tag"}],
                 []
               )

      assert %{
               destination_object: destination_object,
               metadata: metadata,
               data: struct
             } = payload

      assert "-organization/file_info_abstract/unique_id-image.jpeg" = destination_object

      assert %{
               content_length: 11,
               content_type: "text/plain",
               e_tag: "e_tag",
               last_modified: ~U[2024-07-24 01:00:00Z]
             } = metadata

      assert %{
               state: :completed,
               content_length: nil,
               content_type: nil,
               e_tag: "e_tag",
               id: ^struct_id,
               unique_identifier: "unique_id",
               filename: "image.jpeg",
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = struct
    end
  end

  describe "abort_multipart_upload: " do
    test "can abort multipart upload" do
      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg",
          upload_id: "upload_id"
        })

      struct_id = struct.id

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

      assert {:ok, payload} =
               Core.abort_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 %{},
                 []
               )

      assert %{data: struct} = payload

      assert %{
               state: :aborted,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               id: ^struct_id,
               key: "temp/image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = struct
    end
  end

  describe "create_multipart_upload/6: " do
    test "creates upload and expiration job" do
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

      assert {:ok, payload} =
               Core.create_multipart_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 "image.jpeg",
                 %{},
                 basename_prefix: "timestamp"
               )

      assert %{
               multipart_upload: multipart_upload,
               data: struct
             } = payload

      assert %{
               bucket: @bucket,
               key: "temp/-user/timestamp-image.jpeg",
               upload_id: "upload_id"
             } = multipart_upload

      assert %{
               state: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               filename: "image.jpeg",
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: "upload_id"
             } = struct
    end
  end

  describe "complete_upload: " do
    test "can complete upload" do
      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg"
        })

      struct_id = struct.id

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

      assert {:ok, payload} =
               Core.complete_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 %{id: struct_id},
                 %{},
                 []
               )

      assert %{
               metadata: metadata,
               data: struct
             } = payload

      assert %{
               content_length: 11,
               content_type: "text/plain",
               e_tag: "e_tag",
               last_modified: ~U[2024-07-24 01:00:00Z]
             } = metadata

      assert %{
               state: :completed,
               content_length: nil,
               content_type: nil,
               e_tag: "e_tag",
               id: ^struct_id,
               key: "temp/image.jpeg",
               last_modified: nil,
               upload_id: nil
             } = struct
    end
  end

  describe "abort_upload/4: " do
    test "can abort upload" do
      StorageSandbox.set_head_object_responses([
        {@bucket, fn -> {:error, %{code: :not_found}} end}
      ])

      struct =
        Fixture.UserAvatarFileInfo.insert!(%{
          state: :pending,
          filename: "image.jpeg",
          key: "temp/image.jpeg"
        })

      struct_id = struct.id

      assert {:ok, payload} =
               Core.abort_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 struct,
                 %{},
                 []
               )

      assert %{
               data: %{
                 state: :aborted,
                 content_length: nil,
                 content_type: nil,
                 e_tag: nil,
                 id: ^struct_id,
                 key: "temp/image.jpeg",
                 last_modified: nil,
                 upload_id: nil
               }
             } = payload
    end
  end

  describe "create_upload/6: " do
    test "can create upload and job" do
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

      assert {:ok, payload} =
               Core.create_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 "image.jpeg",
                 %{},
                 basename_prefix: "timestamp"
               )

      assert %{
               signed_url: signed_url,
               data: struct
             } = payload

      assert %{
               url: "http://url/temp/-user/timestamp-image.jpeg",
               expires_at: %DateTime{}
             } = signed_url

      assert %{
               state: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               filename: "image.jpeg",
               key: "temp/-user/timestamp-image.jpeg",
               last_modified: nil,
               upload_id: nil
             } = struct

      StorageSandbox.set_head_object_responses([
        {"uppy-test",
         fn ->
           {:error, %{code: :not_found}}
         end}
      ])
    end

    test "returns expected error message if constraint violation occurs in transaction" do
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

      # Here the assoc_id references a record that does not exist which
      # will trigger a foreign key constraint error. The transaction
      # function has to manually call rollback when an error occurs
      # otherwise if `{:error, changeset}` is returned you will get
      # {:error, :rollback} as the result, instead we have to call
      # Repo.rollback(changeset).
      assert {:error, %Ecto.Changeset{}} =
               Core.create_upload(
                 @bucket,
                 {"user_avatar_file_infos", FileInfoAbstract},
                 "image.jpeg",
                 %{assoc_id: 123_456}
               )
    end
  end
end

# defmodule Uppy.CoreTest do
#   use Uppy.Support.DataCase, async: true

#   alias Uppy.Core

#   alias Uppy.Support.{
#     Fixture,
#     Schemas.FileInfoAbstract,
#     StorageSandbox
#   }

#   @bucket "uppy-test"

#   describe "move_to_destination " do
#     test "can move existing object to location" do
#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :completed,
#           filename: "image.jpeg",
#           key: "temp/-user/timestamp-image.jpeg"
#         })

#       struct_id = struct.id

#       StorageSandbox.set_head_object_responses([
#         {@bucket,
#          fn ->
#            {:ok,
#             %{
#               content_length: 11,
#               content_type: "text/plain",
#               e_tag: "e_tag",
#               last_modified: ~U[2024-07-24 01:00:00Z]
#             }}
#          end}
#       ])

#       StorageSandbox.set_put_object_copy_responses([
#         {
#           ~r|.*|,
#           fn ->
#             {:ok,
#              %{
#                body: "body",
#                headers: [
#                  {"x-amz-id-2", "<amz_id>"},
#                  {"x-amz-request-id", "<x_amz_request_id>"},
#                  {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
#                  {"x-amz-server-side-encryption", "<x_amz_server_side_encryption>"},
#                  {"content-type", "<content_type>"},
#                  {"server", "<server>"},
#                  {"content-length", "<content_length>"}
#                ],
#                status_code: 200
#              }}
#           end
#         }
#       ])

#       StorageSandbox.set_delete_object_responses([
#         {
#           ~r|.*|,
#           fn ->
#             {:ok,
#              %{
#                body: "",
#                headers: [
#                  {"x-amz-id-2", "<x_amz_id_2>"},
#                  {"x-amz-request-id", "<x_amz_request_id>"},
#                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                  {"server", "<server>"}
#                ],
#                status_code: 204
#              }}
#           end
#         }
#       ])

#       assert {:ok, payload} =
#                Core.move_to_destination(
#                  @bucket,
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  "permanent/destination_image.jpeg",
#                  []
#                )

#       assert %{resolution: resolution, done: done} = payload

#       assert [Uppy.Phases.MoveToDestination] = done

#       assert %{
#                state: :resolved,
#                bucket: @bucket,
#                query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
#                arguments: %{
#                  destination_object: "permanent/destination_image.jpeg"
#                },
#                value: %{
#                  state: :ready,
#                  content_length: 11,
#                  content_type: nil,
#                  e_tag: "e_tag",
#                  filename: "image.jpeg",
#                  key: "permanent/destination_image.jpeg",
#                  last_modified: %DateTime{},
#                  upload_id: nil
#                }
#              } = resolution
#     end
#   end

#   describe "find_parts: " do
#     test "returns parts" do
#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/-user/timestamp-image.jpeg",
#           upload_id: "upload_id"
#         })

#       struct_id = struct.id

#       StorageSandbox.set_list_parts_responses([
#         {@bucket,
#          fn ->
#            {:ok,
#             [
#               %{
#                 size: 1,
#                 etag: "e_tag",
#                 part_number: 1
#               }
#             ]}
#          end}
#       ])

#       assert {:ok, payload} =
#                Core.find_parts(
#                  @bucket,
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  []
#                )

#       assert %{
#                parts: parts,
#                data: struct
#              } = payload

#       assert [
#                %{
#                  size: 1,
#                  etag: "e_tag",
#                  part_number: 1
#                }
#              ] = parts

#       assert %{
#                state: :pending,
#                content_length: nil,
#                content_type: nil,
#                e_tag: nil,
#                id: ^struct_id,
#                key: "temp/-user/timestamp-image.jpeg",
#                last_modified: nil,
#                upload_id: "upload_id"
#              } = struct
#     end
#   end

#   describe "sign_part: " do
#     test "can pre-sign part" do
#       StorageSandbox.set_sign_part_responses([
#         {@bucket,
#          fn ->
#            {:ok,
#             %{
#               url: "http://url/temp/image.jpeg",
#               expires_at: ~U[2024-07-24 01:00:00Z]
#             }}
#          end}
#       ])

#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/-user/timestamp-image.jpeg",
#           upload_id: "upload_id"
#         })

#       struct_id = struct.id

#       assert {:ok, payload} =
#                Core.sign_part(
#                  @bucket,
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  1,
#                  []
#                )

#       assert %{
#                signed_part: signed_part,
#                data: struct
#              } = payload

#       assert %{
#                url: "http://url/temp/image.jpeg",
#                expires_at: ~U[2024-07-24 01:00:00Z]
#              } = signed_part

#       assert %{
#                content_length: nil,
#                content_type: nil,
#                e_tag: nil,
#                id: ^struct_id,
#                key: "temp/-user/timestamp-image.jpeg",
#                last_modified: nil,
#                upload_id: "upload_id"
#              } = struct
#     end
#   end

#   describe "complete_multipart_upload: " do
#     test "can complete multipart upload" do
#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/-user/timestamp-image.jpeg",
#           upload_id: "upload_id"
#         })

#       struct_id = struct.id

#       StorageSandbox.set_head_object_responses([
#         {@bucket,
#          fn ->
#            {:ok,
#             %{
#               content_length: 11,
#               content_type: "text/plain",
#               e_tag: "e_tag",
#               last_modified: ~U[2024-07-24 01:00:00Z]
#             }}
#          end}
#       ])

#       StorageSandbox.set_complete_multipart_upload_responses([
#         {@bucket, fn -> {:ok, %{}} end}
#       ])

#       assert {:ok, payload} =
#                Core.complete_multipart_upload(
#                  @bucket,
#                  %{},
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  %{unique_identifier: "unique_id"},
#                  [{1, "e_tag"}],
#                  []
#                )

#       assert %{
#                destination_object: destination_object,
#                metadata: metadata,
#                data: struct,
#                jobs: jobs
#              } = payload

#       assert "-organization/file_info_abstract/unique_id-image.jpeg" = destination_object

#       assert %{
#                content_length: 11,
#                content_type: "text/plain",
#                e_tag: "e_tag",
#                last_modified: ~U[2024-07-24 01:00:00Z]
#              } = metadata

#       assert %{
#                state: :completed,
#                content_length: nil,
#                content_type: nil,
#                e_tag: "e_tag",
#                id: ^struct_id,
#                unique_identifier: "unique_id",
#                filename: "image.jpeg",
#                key: "temp/-user/timestamp-image.jpeg",
#                last_modified: nil,
#                upload_id: "upload_id"
#              } = struct

#       StorageSandbox.set_put_object_copy_responses([
#         {"uppy-test",
#          fn ->
#            {:ok,
#             %{
#               body: "body",
#               headers: [
#                 {"x-amz-id-2", "amz_id"},
#                 {"x-amz-request-id", "C6KG1R8WTNFSTX5F"},
#                 {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
#                 {"x-amz-server-side-encryption", "AES256"},
#                 {"content-type", "application/xml"},
#                 {"server", "AmazonS3"},
#                 {"content-length", "224"}
#               ],
#               status_code: 200
#             }}
#          end}
#       ])

#       StorageSandbox.set_delete_object_responses([
#         {"uppy-test",
#          fn ->
#            {:ok,
#             %{
#               body: "",
#               headers: [
#                 {"x-amz-id-2",
#                  "LQXU1lr7kVEJe+MIP6t5vM0rLN3mDSdTkRI3Mw0EV7QZQsSy2dWkO6SEdwxH1ZnLMZ9TBEQjXZ4="},
#                 {"x-amz-request-id", "S8HCXECRERKT8F8S"},
#                 {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                 {"server", "AmazonS3"}
#               ],
#               status_code: 204
#             }}
#          end}
#       ])

#       assert %{move_to_destination: job} = jobs

#       assert %Oban.Job{
#                args:
#                  %{
#                    bucket: "uppy-test",
#                    event: "uppy.move_to_destination",
#                    id: job_id,
#                    query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
#                    source: "user_avatar_file_infos"
#                  } = args,
#                worker: "Uppy.Uploader.Engines.ObanScheduler.MoveToDestinationWorker"
#              } = job

#       assert job_id === struct.id

#       assert {:ok,
#               %{
#                 done: [Uppy.Phases.MoveToDestination],
#                 resolution: resolution
#               }} = perform_job(Uppy.Uploader.Engines.ObanScheduler.MoveToDestinationWorker, args)

#       assert %{
#                state: :completed,
#                filename: "image.jpeg"
#              } = struct

#       assert %Uppy.Resolution{
#                bucket: "uppy-test",
#                query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
#                state: :resolved,
#                arguments: %{destination_object: dest_object},
#                value: struct
#              } = resolution

#       assert %{state: :ready} = struct

#       assert dest_object === struct.key
#     end
#   end

#   describe "abort_multipart_upload: " do
#     test "can abort multipart upload" do
#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/image.jpeg",
#           upload_id: "upload_id"
#         })

#       struct_id = struct.id

#       StorageSandbox.set_abort_multipart_upload_responses([
#         {
#           @bucket,
#           fn ->
#             {:ok,
#              %{
#                body: "",
#                headers: [
#                  {"x-amz-id-2", "x_amz_id"},
#                  {"x-amz-request-id", "x_amz_request_id"},
#                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                  {"server", "AmazonS3"}
#                ],
#                status_code: 204
#              }}
#           end
#         }
#       ])

#       assert {:ok, payload} =
#                Core.abort_multipart_upload(
#                  @bucket,
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  %{},
#                  []
#                )

#       assert %{data: struct} = payload

#       assert %{
#                state: :aborted,
#                content_length: nil,
#                content_type: nil,
#                e_tag: nil,
#                id: ^struct_id,
#                key: "temp/image.jpeg",
#                last_modified: nil,
#                upload_id: "upload_id"
#              } = struct
#     end
#   end

#   describe "create_multipart_upload/6: " do
#     test "creates upload and expiration job" do
#       StorageSandbox.set_create_multipart_upload_responses([
#         {
#           @bucket,
#           fn object ->
#             {:ok,
#              %{
#                key: object,
#                bucket: @bucket,
#                upload_id: "upload_id"
#              }}
#           end
#         }
#       ])

#       assert {:ok, payload} =
#                Core.create_multipart_upload(
#                  @bucket,
#                  %{},
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  "image.jpeg",
#                  %{},
#                  basename_prefix: "timestamp"
#                )

#       assert %{
#                multipart_upload: multipart_upload,
#                data: struct,
#                jobs: jobs
#              } = payload

#       assert %{
#                bucket: @bucket,
#                key: "temp/-user/timestamp-image.jpeg",
#                upload_id: "upload_id"
#              } = multipart_upload

#       assert %{
#                state: :pending,
#                content_length: nil,
#                content_type: nil,
#                e_tag: nil,
#                filename: "image.jpeg",
#                key: "temp/-user/timestamp-image.jpeg",
#                last_modified: nil,
#                upload_id: "upload_id"
#              } = struct

#       assert %{abort_expired_multipart_upload: job} = jobs

#       assert %Oban.Job{
#                args:
#                  %{
#                    bucket: "uppy-test",
#                    event: "uppy.abort_expired_multipart_upload",
#                    id: job_id,
#                    query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
#                    source: "user_avatar_file_infos"
#                  } = args,
#                worker: "Uppy.Uploader.Engines.ObanScheduler.ExpiredMultipartUploadWorker"
#              } = job

#       assert job_id === struct.id

#       StorageSandbox.set_abort_multipart_upload_responses([
#         {"uppy-test",
#          fn ->
#            {:ok,
#             %{
#               body: "",
#               headers: [
#                 {"x-amz-id-2", "LQXU1lr7kVEJe="},
#                 {"x-amz-request-id", "S8HCXECRERKT8F8S"},
#                 {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                 {"server", "AmazonS3"}
#               ],
#               status_code: 204
#             }}
#          end}
#       ])

#       assert {:ok,
#               %{
#                 metadata: metadata,
#                 data: struct
#               }} =
#                perform_job(Uppy.Uploader.Engines.ObanScheduler.ExpiredMultipartUploadWorker, args)

#       assert %{
#                body: "",
#                headers: [
#                  {"x-amz-id-2", "LQXU1lr7kVEJe="},
#                  {"x-amz-request-id", "S8HCXECRERKT8F8S"},
#                  {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                  {"server", "AmazonS3"}
#                ],
#                status_code: 204
#              } = metadata

#       assert %{
#                state: :expired,
#                filename: "image.jpeg"
#              } = struct
#     end
#   end

#   describe "complete_upload: " do
#     test "can complete upload" do
#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/image.jpeg"
#         })

#       struct_id = struct.id

#       StorageSandbox.set_head_object_responses([
#         {@bucket,
#          fn ->
#            {:ok,
#             %{
#               content_length: 11,
#               content_type: "text/plain",
#               e_tag: "e_tag",
#               last_modified: ~U[2024-07-24 01:00:00Z]
#             }}
#          end}
#       ])

#       assert {:ok, payload} =
#                Core.complete_upload(
#                  @bucket,
#                  %{},
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  %{id: struct_id},
#                  %{},
#                  []
#                )

#       assert %{
#                metadata: metadata,
#                data: struct,
#                jobs: jobs
#              } = payload

#       assert %{
#                content_length: 11,
#                content_type: "text/plain",
#                e_tag: "e_tag",
#                last_modified: ~U[2024-07-24 01:00:00Z]
#              } = metadata

#       assert %{
#                state: :completed,
#                content_length: nil,
#                content_type: nil,
#                e_tag: "e_tag",
#                id: ^struct_id,
#                key: "temp/image.jpeg",
#                last_modified: nil,
#                upload_id: nil
#              } = struct

#       StorageSandbox.set_put_object_copy_responses([
#         {"uppy-test",
#          fn ->
#            {:ok,
#             %{
#               body: "body",
#               headers: [
#                 {"x-amz-id-2", "amz_id"},
#                 {"x-amz-request-id", "C6KG1R8WTNFSTX5F"},
#                 {"date", "Sat, 16 Sep 2023 01:57:35 GMT"},
#                 {"x-amz-server-side-encryption", "AES256"},
#                 {"content-type", "application/xml"},
#                 {"server", "AmazonS3"},
#                 {"content-length", "224"}
#               ],
#               status_code: 200
#             }}
#          end}
#       ])

#       StorageSandbox.set_delete_object_responses([
#         {"uppy-test",
#          fn ->
#            {:ok,
#             %{
#               body: "",
#               headers: [
#                 {"x-amz-id-2",
#                  "LQXU1lr7kVEJe+MIP6t5vM0rLN3mDSdTkRI3Mw0EV7QZQsSy2dWkO6SEdwxH1ZnLMZ9TBEQjXZ4="},
#                 {"x-amz-request-id", "S8HCXECRERKT8F8S"},
#                 {"date", "Sat, 16 Sep 2023 04:13:38 GMT"},
#                 {"server", "AmazonS3"}
#               ],
#               status_code: 204
#             }}
#          end}
#       ])

#       assert %{move_to_destination: job} = jobs

#       assert %Oban.Job{
#                args:
#                  %{
#                    bucket: "uppy-test",
#                    event: "uppy.move_to_destination",
#                    id: job_id,
#                    query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
#                    source: "user_avatar_file_infos"
#                  } = args,
#                worker: "Uppy.Uploader.Engines.ObanScheduler.MoveToDestinationWorker"
#              } = job

#       assert job_id === struct.id

#       assert {:ok,
#               %{
#                 done: [Uppy.Phases.MoveToDestination],
#                 resolution: resolution
#               }} = perform_job(Uppy.Uploader.Engines.ObanScheduler.MoveToDestinationWorker, args)

#       assert %{
#                state: :completed,
#                filename: "image.jpeg"
#              } = struct

#       assert %Uppy.Resolution{
#                bucket: "uppy-test",
#                query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
#                state: :resolved,
#                arguments: %{destination_object: dest_object},
#                value: struct
#              } = resolution

#       assert %{state: :ready} = struct

#       assert dest_object === struct.key
#     end
#   end

#   describe "abort_upload/4: " do
#     test "can abort upload" do
#       StorageSandbox.set_head_object_responses([
#         {@bucket, fn -> {:error, %{code: :not_found}} end}
#       ])

#       struct =
#         Fixture.UserAvatarFileInfo.insert!(%{
#           state: :pending,
#           filename: "image.jpeg",
#           key: "temp/image.jpeg"
#         })

#       struct_id = struct.id

#       assert {:ok, payload} =
#                Core.abort_upload(
#                  @bucket,
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  struct,
#                  %{},
#                  []
#                )

#       assert %{
#                data: %{
#                  state: :aborted,
#                  content_length: nil,
#                  content_type: nil,
#                  e_tag: nil,
#                  id: ^struct_id,
#                  key: "temp/image.jpeg",
#                  last_modified: nil,
#                  upload_id: nil
#                }
#              } = payload
#     end
#   end

#   describe "create_upload/6: " do
#     test "can create upload and job" do
#       StorageSandbox.set_pre_sign_responses([
#         {
#           @bucket,
#           fn _http_method, object ->
#             {
#               :ok,
#               %{
#                 url: "http://url/#{object}",
#                 expires_at: ~U[2024-07-24 01:00:00Z]
#               }
#             }
#           end
#         }
#       ])

#       assert {:ok, payload} =
#                Core.create_upload(
#                  @bucket,
#                  %{},
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  "image.jpeg",
#                  %{},
#                  basename_prefix: "timestamp"
#                )

#       assert %{
#                signed_url: signed_url,
#                data: struct,
#                jobs: jobs
#              } = payload

#       assert %{
#                url: "http://url/temp/-user/timestamp-image.jpeg",
#                expires_at: %DateTime{}
#              } = signed_url

#       assert %{
#                state: :pending,
#                content_length: nil,
#                content_type: nil,
#                e_tag: nil,
#                filename: "image.jpeg",
#                key: "temp/-user/timestamp-image.jpeg",
#                last_modified: nil,
#                upload_id: nil
#              } = struct

#       StorageSandbox.set_head_object_responses([
#         {"uppy-test",
#          fn ->
#            {:error, %{code: :not_found}}
#          end}
#       ])

#       assert %{abort_expired_upload: job} = jobs

#       assert %Oban.Job{
#                args:
#                  %{
#                    bucket: "uppy-test",
#                    event: "uppy.abort_expired_upload",
#                    id: job_id,
#                    query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
#                    source: "user_avatar_file_infos"
#                  } = args,
#                worker: "Uppy.Uploader.Engines.ObanScheduler.ExpiredUploadWorker"
#              } = job

#       assert job_id === struct.id

#       assert {:ok, %{data: struct}} =
#                perform_job(Uppy.Uploader.Engines.ObanScheduler.ExpiredUploadWorker, args)

#       assert %{state: :expired, filename: "image.jpeg"} = struct
#     end

#     test "returns expected error message if constraint violation occurs in transaction" do
#       StorageSandbox.set_pre_sign_responses([
#         {
#           @bucket,
#           fn _http_method, object ->
#             {
#               :ok,
#               %{
#                 url: "http://url/#{object}",
#                 expires_at: ~U[2024-07-24 01:00:00Z]
#               }
#             }
#           end
#         }
#       ])

#       # Here the assoc_id references a record that does not exist which
#       # will trigger a foreign key constraint error. The transaction
#       # function has to manually call rollback when an error occurs
#       # otherwise if `{:error, changeset}` is returned you will get
#       # {:error, :rollback} as the result, instead we have to call
#       # Repo.rollback(changeset).
#       assert {:error, %Ecto.Changeset{}} =
#                Core.create_upload(
#                  @bucket,
#                  %{},
#                  {"user_avatar_file_infos", FileInfoAbstract},
#                  "image.jpeg",
#                  %{assoc_id: 123_456}
#                )
#     end
#   end
# end
