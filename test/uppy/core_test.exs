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
          destination_query: Uppy.SchemasPG.Upload,
          source_bucket: @bucket,
          source_query: Uppy.SchemasPG.PendingUpload,
          scheduler: Uppy.Core.Scheduler.None,
          storage: CloudCache.Adapters.S3
        )
    }
  end

  describe "start_upload/3" do
    test "can start an upload", ctx do
      assert {:ok,
              %{
                data: data,
                job: :none,
                pre_signed_url: pre_signed_url
              }} =
               Uppy.Core.start_upload(
                 ctx.state,
                 %{key: "test-object", unique_identifier: "PPXQFVY"},
                 []
               )

      assert %Uppy.SchemasPG.PendingUpload{
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
      assert {:ok, %{data: pending_upload}} =
        Uppy.Core.start_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, [])

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

      assert %Uppy.SchemasPG.PendingUpload{
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
      {:ok, %{data: pending_upload}} =
      Uppy.Core.start_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, [])

      assert {:ok, _} = LocalStack.put_object(@bucket, "test-object", "content", [])

      assert {:ok,
              %{
                schema_data: schema_data,
                job: :none
              }} =
               Uppy.Core.complete_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, %{}, [])

      assert %Uppy.SchemasPG.PendingUpload{
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

  # describe "find_parts/2" do
  #   test "can find parts", ctx do
  #     %{pending_upload: pending_upload} = upload_context(ctx)

  #     assert {:ok,
  #             %{
  #               schema_data: schema_data,
  #               parts: parts
  #             }} =
  #              Uppy.Core.find_parts(ctx.state, %{key: "test-object"}, [])

  #     assert %Uppy.SchemasPG.PendingUpload{
  #              id: id,
  #              state: "pending",
  #              unique_identifier: "PPXQFVY",
  #              key: "test-object",
  #              upload_id: nil,
  #              content_length: nil,
  #              content_type: nil,
  #              etag: nil
  #            } = schema_data

  #     assert [] = parts
  #     assert id === pending_upload.id
  #   end
  # end

  # describe "start_multipart_upload/3" do
  #   test "can start a multipart upload", ctx do
  #     assert {:ok,
  #             %{
  #               create_multipart_upload: create_mpu_result,
  #               schema_data: schema_data,
  #               job: :none
  #             }} =
  #              Uppy.Core.start_multipart_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, [])

  #     assert %Uppy.SchemasPG.PendingUpload{
  #              id: _,
  #              state: "pending",
  #              unique_identifier: "PPXQFVY",
  #              key: "test-object",
  #              upload_id: nil,
  #              content_length: nil,
  #              content_type: nil,
  #              etag: nil
  #            } = schema_data
  #   end
  # end
end
