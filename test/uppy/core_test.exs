defmodule Uppy.CoreTest do
  use Uppy.Support.DataCase
  doctest Uppy.Core

  @bucket "test-bucket"

  setup do
    %{
      state: Uppy.Core.new(
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
               Uppy.Core.start_upload(ctx.state, %{key: "test-object", unique_identifier: "PPXQFVY"}, [])

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
end
