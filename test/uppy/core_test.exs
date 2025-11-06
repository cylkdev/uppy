defmodule Uppy.CoreTest do
  use Uppy.Support.DataCase
  doctest Uppy.Core

  alias CloudCache.Adapters.S3.Testing.LocalStack

  @bucket "test-bucket"
  @region "us-west-1"

  setup_all do
    assert {:ok, _} = LocalStack.head_or_create_bucket(@region, @bucket, [])
  end

  setup do
    %{
      state:
        Uppy.Core.new(
          database: EctoShorts.Actions,
          destination_bucket: @bucket,
          destination_query: Uppy.Schemas.Upload,
          source_bucket: @bucket,
          source_query: Uppy.Schemas.PendingUpload,
          scheduler: Uppy.Core.Scheduler.None,
          storage: CloudCache.Adapters.S3
        )
    }
  end

  describe "start_upload/3" do
    test "can start an upload", ctx do
      assert {:ok,
              %{
                schema_data: data,
                job: :none,
                pre_signed_url: pre_signed_url
              }} =
               Uppy.Core.start_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               id: _,
               state: "pending",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: nil,
               content_length: nil,
               content_type: nil,
               etag: nil
             } = data

      assert %{
               key: "test-object",
               url: url,
               expires_in: 60,
               expires_at: %DateTime{}
             } = pre_signed_url

      assert String.contains?(url, "test-object")
    end
  end

  describe "abort_upload/4" do
    test "can abort an upload", ctx do
      assert {:ok, %{schema_data: pending_upload}} =
               Uppy.Core.start_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert {:ok,
              %{
                schema_data: schema_data,
                job: :none
              }} =
               Uppy.Core.abort_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 %{},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               id: id,
               state: "aborted",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: nil,
               content_length: nil,
               content_type: nil,
               etag: nil
             } = schema_data

      assert id === pending_upload.id
    end
  end

  describe "complete_upload/4" do
    test "can complete an upload", ctx do
      {:ok, %{schema_data: pending_upload}} =
        Uppy.Core.start_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, [])

      assert {:ok, _} = LocalStack.put_object(@bucket, "test-object", "content", [])

      assert {:ok,
              %{
                schema_data: schema_data,
                job: :none
              }} =
               Uppy.Core.complete_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 %{},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               id: id,
               state: "completed",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: nil,
               content_length: _,
               content_type: _,
               etag: _
             } = schema_data

      assert id === pending_upload.id
    end
  end

  describe "save_upload/4" do
    test "can save an upload", ctx do
      assert {:ok,
              %{
                schema_data: _,
                job: :none,
                pre_signed_url: _
              }} =
               Uppy.Core.start_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert {:ok, _} = LocalStack.put_object(@bucket, "test-object", "content", [])

      assert {:ok, _} = LocalStack.head_or_create_bucket(@region, "test-bucket-2", [])

      assert {:ok,
              %{
                copy_object: _,
                metadata: _,
                source_schema_data: source_schema_data,
                destination_schema_data: destination_schema_data
              }} =
               Uppy.Core.save_upload(
                 %{ctx.state | destination_bucket: "test-bucket-2"},
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               id: _,
               state: "pending",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: nil,
               content_length: _,
               content_type: _,
               etag: _
             } = source_schema_data

      assert %Uppy.Schemas.Upload{
               id: _,
               unique_identifier: "PPXQFVY",
               key: "test-object",
               content_length: _,
               content_type: _,
               etag: _
             } = destination_schema_data
    end
  end

  describe "find_parts/2" do
    test "can find parts", ctx do
      assert {:ok,
              %{
                create_multipart_upload: _,
                schema_data: %Uppy.Schemas.PendingUpload{upload_id: upload_id},
                job: :none
              }} =
               Uppy.Core.start_multipart_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      content = (1_024 * 5) |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)

      assert {:ok, _} = LocalStack.upload_part(@bucket, "test-object", upload_id, 1, content, [])

      assert {:ok,
              %{
                schema_data: schema_data,
                parts: parts
              }} =
               Uppy.Core.find_parts(ctx.state, %{key: "test-object"}, [])

      assert %Uppy.Schemas.PendingUpload{
               id: _,
               state: "pending",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: ^upload_id,
               content_length: nil,
               content_type: nil,
               etag: nil
             } = schema_data

      assert %{
               body: %{parts: [%{size: _, etag: _, part_number: 1}]}
             } = parts
    end
  end

  describe "start_multipart_upload/3" do
    test "can start a multipart upload", ctx do
      assert {:ok,
              %{
                create_multipart_upload: create_mpu_result,
                schema_data: schema_data,
                job: :none
              }} =
               Uppy.Core.start_multipart_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               id: _,
               state: "pending",
               unique_identifier: "PPXQFVY",
               key: "test-object",
               upload_id: _,
               content_length: nil,
               content_type: nil,
               etag: nil
             } = schema_data

      assert %{
               body: %{
                 key: "test-object",
                 bucket: "test-bucket",
                 upload_id: multipart_upload_id
               }
             } = create_mpu_result

      assert multipart_upload_id === schema_data.upload_id
    end
  end

  describe "abort_multipart_upload/4" do
    test "can abort a multipart upload", ctx do
      assert {:ok, start_mpu} =
               Uppy.Core.start_multipart_upload(
                 ctx.state,
                 %{key: "test-object-2", unique_identifier: "PPXQFVY"},
                 []
               )

      assert {:ok,
              %{
                schema_data: aborted_schema_data,
                job: :none
              }} =
               Uppy.Core.abort_multipart_upload(
                 ctx.state,
                 %{key: "test-object-2", unique_identifier: "PPXQFVY"},
                 %{},
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               state: "aborted",
               unique_identifier: "PPXQFVY",
               key: "test-object-2"
             } = aborted_schema_data

      assert aborted_schema_data.id === start_mpu.schema_data.id
      assert aborted_schema_data.upload_id === start_mpu.schema_data.upload_id
    end
  end

  describe "complete_multipart_upload/5" do
    test "can complete a multipart upload", ctx do
      assert {:ok,
              %{
                create_multipart_upload: _,
                schema_data: %{upload_id: upload_id},
                job: :none
              }} =
               Uppy.Core.start_multipart_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      content = (1_024 * 5) |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)

      assert {:ok, _} = LocalStack.upload_part(@bucket, "test-object", upload_id, 1, content, [])

      assert {:ok,
              %{
                schema_data: _,
                parts: %{body: %{parts: [%{etag: etag, part_number: 1}]}}
              }} =
               Uppy.Core.find_parts(ctx.state, %{key: "test-object"}, [])

      assert {:ok,
              %{
                metadata: _,
                schema_data: completed_schema_data,
                job: :none
              }} =
               Uppy.Core.complete_multipart_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 %{},
                 [{1, etag}],
                 []
               )

      assert %Uppy.Schemas.PendingUpload{
               state: "completed",
               unique_identifier: "PPXQFVY",
               key: "test-object"
             } = completed_schema_data

      assert completed_schema_data.content_length
      assert completed_schema_data.content_type
      assert completed_schema_data.etag
      assert completed_schema_data.last_modified
    end
  end
end
