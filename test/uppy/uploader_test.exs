defmodule Uppy.UploaderTest do
  use Uppy.Support.DataCase, async: true

  alias Uppy.{
    Support.StorageSandbox,
    Uploader
  }

  defmodule MockUploader do
    use Uppy.Uploader,
      bucket: "test-bucket",
      query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract}

    @default_permanent_object_params %{
      resource_name: "user_avatar",
      partition_name: "organization"
    }

    @default_temporary_object_params %{
      partition_name: "user",
      basename_prefix: "temp"
    }

    def build_object_path_params(params) do
      params
      |> Map.update(
        :permanent_object,
        @default_permanent_object_params,
        &Map.merge(@default_permanent_object_params, &1)
      )
      |> Map.update(
        :temporary_object,
        @default_temporary_object_params,
        &Map.merge(@default_temporary_object_params, &1)
      )
    end
  end

  describe "bucket/0" do
    test "returns expected response" do
      assert "test-bucket" = Uploader.bucket(MockUploader)
    end
  end

  describe "query/0" do
    test "returns expected response" do
      assert {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract} =
               Uploader.query(MockUploader)
    end
  end

  describe "path/0" do
    test "returns expected response" do
      assert %{
               permanent_object: %{
                 resource_name: "user_avatar",
                 partition_name: "organization"
               },
               temporary_object: %{
                 partition_name: "user",
                 basename_prefix: "temp"
               }
             } === Uploader.path(MockUploader)
    end
  end

  describe "create_upload: " do
    test "creates record in pending state and job" do
      StorageSandbox.set_pre_sign_responses([
        {
          "test-bucket",
          fn _http_method, object ->
            {:ok,
             %{
               url: "http://url/#{object}",
               expires_at: ~U[2024-07-24 01:00:00Z]
             }}
          end
        }
      ])

      StorageSandbox.set_head_object_responses([
        {
          "test-bucket",
          fn -> {:error, %{code: :not_found}} end
        }
      ])

      assert {:ok, payload} =
               Uploader.create_upload(
                 MockUploader,
                 %{
                   temporary_object: %{
                     partition_id: "AB",
                     basename_prefix: "temp_prefix"
                   }
                 },
                 %{
                   filename: "image.jpeg"
                   #  assoc_id: parent.id
                 },
                 []
               )

      assert %{
               signed_url: signed_url,
               schema_data: schema_data,
               jobs: jobs
             } = payload

      assert %{
               url: "http://url/temp/BA-user/temp_prefix-image.jpeg",
               expires_at: %DateTime{}
             } = signed_url

      assert %Uppy.Support.Schemas.FileInfoAbstract{
               state: :pending,
               content_length: nil,
               content_type: nil,
               e_tag: nil,
               filename: "image.jpeg",
               key: "temp/BA-user/temp_prefix-image.jpeg",
               last_modified: nil,
               upload_id: nil
             } = schema_data

      assert %{abort_expired_upload: %Oban.Job{args: args}} = jobs

      assert %{
               bucket: "test-bucket",
               event: "uppy.abort_expired_upload",
               id: job_id,
               query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
               source: "user_avatar_file_infos"
             } = args

      assert job_id === schema_data.id

      assert {:ok, %{schema_data: schema_data}} =
               perform_job(Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredUploadWorker, args)

      assert %Uppy.Support.Schemas.FileInfoAbstract{state: :expired, filename: "image.jpeg"} =
               schema_data
    end
  end

  describe "abort_upload/4: " do
    test "updates record state to aborted" do
      StorageSandbox.set_pre_sign_responses([
        {
          "test-bucket",
          fn _http_method, object ->
            {:ok,
             %{
               url: "http://url/#{object}",
               expires_at: ~U[2024-07-24 01:00:00Z]
             }}
          end
        }
      ])

      StorageSandbox.set_head_object_responses([
        {"test-bucket", fn -> {:error, %{code: :not_found}} end}
      ])

      assert {:ok, %{schema_data: %Uppy.Support.Schemas.FileInfoAbstract{id: schema_id}}} =
               Uploader.create_upload(
                 MockUploader,
                 %{
                   temporary_object: %{
                     partition_id: "AB",
                     basename_prefix: "temp_prefix"
                   }
                 },
                 %{
                   filename: "image.jpeg"
                   #  assoc_id: parent.id,
                 },
                 []
               )

      assert {:ok,
              %{
                schema_data: %Uppy.Support.Schemas.FileInfoAbstract{
                  state: :aborted,
                  content_length: nil,
                  content_type: nil,
                  e_tag: nil,
                  id: ^schema_id,
                  key: "temp/BA-user/temp_prefix-image.jpeg",
                  last_modified: nil,
                  upload_id: nil
                }
              }} = Uploader.abort_upload(MockUploader, %{id: schema_id}, %{}, [])
    end
  end

  describe "complete_upload: " do
    test "updates state to completed and moves object to destination in storage" do
      StorageSandbox.set_pre_sign_responses([
        {
          "test-bucket",
          fn _http_method, object ->
            {:ok,
             %{
               url: "http://url/#{object}",
               expires_at: ~U[2024-07-24 01:00:00Z]
             }}
          end
        }
      ])

      StorageSandbox.set_head_object_responses([
        {"test-bucket",
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
        {"test-bucket",
         fn ->
           {:ok,
            %{
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
         end}
      ])

      StorageSandbox.set_delete_object_responses([
        {"test-bucket",
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

      assert {:ok, %{schema_data: %Uppy.Support.Schemas.FileInfoAbstract{id: schema_id}}} =
               Uploader.create_upload(
                 MockUploader,
                 %{
                   temporary_object: %{
                     partition_id: "AB",
                     basename_prefix: "temp_prefix"
                   }
                 },
                 %{
                   # ,
                   filename: "image.jpeg"
                   #  assoc_id: parent.id
                 },
                 []
               )

      assert {:ok, payload} =
               Uploader.complete_upload(
                 MockUploader,
                 %{permanent_object: %{partition_id: "ORG_ID"}},
                 %{id: schema_id},
                 %{unique_identifier: "test_unique_id"},
                 []
               )

      assert %{
               metadata: metadata,
               schema_data: schema_data,
               jobs: jobs
             } = payload

      assert %{
               content_length: 11,
               content_type: "text/plain",
               e_tag: "e_tag",
               last_modified: ~U[2024-07-24 01:00:00Z]
             } = metadata

      assert %Uppy.Support.Schemas.FileInfoAbstract{
               state: :completed,
               content_length: nil,
               content_type: nil,
               e_tag: "e_tag",
               id: ^schema_id,
               key: "temp/BA-user/temp_prefix-image.jpeg",
               last_modified: nil,
               upload_id: nil
             } = schema_data

      assert %{move_to_destination: %Oban.Job{args: args}} = jobs

      assert %{
               id: ^schema_id,
               bucket: "test-bucket",
               destination_object: dest_object,
               event: "uppy.move_to_destination",
               query: "Elixir.Uppy.Support.Schemas.FileInfoAbstract",
               source: "user_avatar_file_infos"
             } = args

      assert "DI_GRO-organization/user_avatar/test_unique_id-image.jpeg" === dest_object

      assert {:ok,
              %{
                done: [Uppy.Phases.MoveToDestination],
                resolution: resolution
              }} =
               perform_job(Uppy.Schedulers.ObanScheduler.Workers.MoveToDestinationWorker, args)

      assert %Uppy.Support.Schemas.FileInfoAbstract{
               state: :completed,
               filename: "image.jpeg"
             } = schema_data

      assert %Uppy.Resolution{
               bucket: "test-bucket",
               query: {"user_avatar_file_infos", Uppy.Support.Schemas.FileInfoAbstract},
               state: :resolved,
               arguments: %{destination_object: dest_object},
               value: schema_data
             } = resolution

      assert %Uppy.Support.Schemas.FileInfoAbstract{state: :ready} = schema_data

      assert dest_object === schema_data.key
    end
  end
end
