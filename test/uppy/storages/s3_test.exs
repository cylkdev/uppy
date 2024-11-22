defmodule Uppy.Storages.S3Test do
  use ExUnit.Case, async: true
  alias Uppy.Storages.S3

  @moduletag :external

  @bucket "uppy-test"

  setup_all do
    {:ok, _} = S3.put_object("uppy-test", "seed.txt", "Hello world!", [])
  end

  describe "download_chunk_stream/4: " do
    test "returns expected response" do
      assert "Hello world!" =
               @bucket
               |> S3.download_chunk_stream("seed.txt", 4, [])
               |> elem(1)
               |> Task.async_stream(fn %{start_byte: start_byte, end_byte: end_byte} ->
                 S3.get_chunk!(
                   @bucket,
                   "seed.txt",
                   start_byte,
                   end_byte,
                   []
                 )
               end)
               |> Enum.map_join(fn {:ok, {_start_byte, body}} -> body end)
    end
  end

  describe "get_chunk/5: " do
    test "returns expected response" do
      assert {:ok, {0, "Hello"}} =
               S3.get_chunk(
                 @bucket,
                 "seed.txt",
                 0,
                 4,
                 http_opts: [disable_json_decoding?: true]
               )
    end
  end

  describe "list_objects/3: " do
    test "returns expected response" do
      assert {:ok,
              [
                %{
                  e_tag: _,
                  key: _,
                  last_modified: _,
                  owner: _,
                  size: _,
                  storage_class: _
                }
                | _
              ]} = S3.list_objects(@bucket, [])
    end
  end

  describe "get_object/3: " do
    test "returns expected response" do
      assert {:ok, "Hello world!"} = S3.get_object(@bucket, "seed.txt", [])
    end
  end

  describe "head_object/3: " do
    test "returns expected response" do
      assert {
               :ok,
               %{
                 last_modified: _,
                 e_tag: _,
                 content_length: _,
                 content_type: _
               }
             } = S3.head_object(@bucket, "seed.txt", [])
    end
  end

  describe "presigned_url/3: " do
    test "returns expected response for POST request" do
      assert {
               :ok,
               %{
                 expires_at: _,
                 key: "example.txt",
                 url: _
               }
             } = S3.presigned_url(@bucket, :post, "example.txt", [])
    end

    test "returns expected response for PUT request" do
      assert {
               :ok,
               %{
                 expires_at: _,
                 key: "example.txt",
                 url: _
               }
             } = S3.presigned_url(@bucket, :put, "example.txt", [])
    end
  end

  describe "put_object_copy/5: " do
    test "returns expected response" do
      assert {:ok,
              %{
                body: _,
                headers: _,
                status_code: 200
              }} =
               S3.put_object_copy(
                 @bucket,
                 "seed_copy.txt",
                 @bucket,
                 "seed.txt",
                 []
               )
    end
  end

  describe "put_object/4: " do
    test "returns expected response" do
      assert {:ok,
              %{
                body: _,
                headers: _,
                status_code: 200
              }} =
               S3.put_object(
                 @bucket,
                 "example_put_object.txt",
                 "Hello World",
                 []
               )
    end
  end

  describe "delete_object/3: " do
    test "returns expected response" do
      assert {:ok,
              %{
                body: _,
                headers: _,
                status_code: 200
              }} =
               S3.put_object(
                 @bucket,
                 "example_delete_object.txt",
                 "Hello World",
                 []
               )

      assert {:ok,
              %{
                body: "",
                headers: _,
                status_code: 204
              }} =
               S3.delete_object(
                 @bucket,
                 "example_delete_object.txt",
                 []
               )
    end
  end

  describe "multipart upload: " do
    test "can complete multipart upload" do
      assert {:ok,
              %{
                key: "image.jpeg",
                bucket: @bucket,
                upload_id: upload_id
              }} = S3.initiate_multipart_upload(@bucket, "image.jpeg", [])

      expected_multipart_upload = %{
        key: "image.jpeg",
        upload_id: upload_id
      }

      assert {:ok,
              %{
                bucket: @bucket,
                key_marker: "",
                upload_id_marker: "",
                uploads: uploads
              }} = S3.list_multipart_uploads(@bucket, [])

      assert ^expected_multipart_upload = Enum.find(uploads, &(&1.upload_id === upload_id))

      part_number = 1

      assert {:ok,
              %{
                key: "image.jpeg",
                url: presigned_url,
                expires_at: _
              }} =
               S3.presigned_url(
                 @bucket,
                 :put,
                 "image.jpeg",
                 query_params: %{
                   "uploadId" => upload_id,
                   "partNumber" => part_number
                 }
               )

      # part size needs to be at least 5MB
      payload =
        (1_024 * 1_024 * 10)
        |> :crypto.strong_rand_bytes()
        |> Base.encode64()

      assert {:ok, {body, response}} =
               Uppy.HTTP.put(presigned_url, payload, [], disable_json_encoding?: true)

      assert "" = body

      assert %Uppy.HTTP.Finch.Response{
               status: 200,
               body: "",
               request: %Finch.Request{
                 method: "PUT",
                 path: "/uppy-test/image.jpeg"
               }
             } = response

      assert {:ok,
              [
                %{
                  size: _,
                  e_tag: part_e_tag,
                  part_number: ^part_number
                }
              ]} = S3.list_parts(@bucket, "image.jpeg", upload_id, [])

      assert {:ok,
              %{
                bucket: @bucket,
                etag: _,
                key: "image.jpeg",
                location: _
              }} =
               S3.complete_multipart_upload(
                 @bucket,
                 "image.jpeg",
                 upload_id,
                 [{part_number, part_e_tag}],
                 []
               )
    end

    test "can abort multipart upload" do
      assert {:ok,
              %{
                key: "image.jpeg",
                bucket: @bucket,
                upload_id: upload_id
              }} = S3.initiate_multipart_upload(@bucket, "image.jpeg", [])

      expected_multipart_upload = %{
        key: "image.jpeg",
        upload_id: upload_id
      }

      assert {:ok,
              %{
                bucket: @bucket,
                key_marker: "",
                upload_id_marker: "",
                uploads: uploads
              }} = S3.list_multipart_uploads(@bucket, [])

      assert ^expected_multipart_upload = Enum.find(uploads, &(&1.upload_id === upload_id))

      part_number = 1

      assert {:ok,
              %{
                key: "image.jpeg",
                url: presigned_url,
                expires_at: _
              }} =
               S3.presigned_url(
                 @bucket,
                 :put,
                 "image.jpeg",
                 query_params: %{
                   "uploadId" => upload_id,
                   "partNumber" => part_number
                 }
               )

      # part size needs to be at least 5MB
      payload =
        (1_024 * 1_024 * 10)
        |> :crypto.strong_rand_bytes()
        |> Base.encode64()

      assert {:ok, {body, response}} =
               Uppy.HTTP.put(presigned_url, payload, [], disable_json_encoding?: true)

      assert "" = body

      assert %Uppy.HTTP.Finch.Response{
               status: 200,
               body: "",
               request: %Finch.Request{
                 method: "PUT",
                 path: "/uppy-test/image.jpeg"
               }
             } = response

      assert {:ok,
              [
                %{
                  size: _,
                  e_tag: _,
                  part_number: ^part_number
                }
              ]} = S3.list_parts(@bucket, "image.jpeg", upload_id, [])

      assert {:ok,
              %{
                body: "",
                headers: _,
                status_code: 204
              }} = S3.abort_multipart_upload(@bucket, "image.jpeg", upload_id, [])
    end
  end
end
