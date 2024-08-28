defmodule Uppy.Storages.S3Test do
  use ExUnit.Case, async: true

  @moduletag :external

  @bucket "uppy-test"

  describe "download_chunk_stream/4: " do
    test "returns expected response" do
      assert {:ok, stream} = Uppy.Storages.S3.download_chunk_stream(@bucket, "example.txt", 4)

      assert "Hello world!" =
        stream
        |> Task.async_stream(fn %{start_byte: start_byte, end_byte: end_byte} ->
          Uppy.Storages.S3.get_chunk!(
            @bucket,
            "example.txt",
            start_byte,
            end_byte
          )
        end)
        |> Enum.map_join("", fn {:ok, {_start_byte, body}} -> body end)
    end
  end

  describe "get_chunk/5: " do
    test "returns expected response" do
      assert {:ok, {0, "Hello"}} =
        Uppy.Storages.S3.get_chunk(
          @bucket,
          "example.txt",
          0,
          4,
          http_opts: [disable_json_decoding?: true]
        )
    end
  end

  describe "list_objects/3: " do
    test "returns expected response" do
      assert {:ok, objects} = Uppy.Storages.S3.list_objects(@bucket)

      expected_object =
        %{
          e_tag: "e06f81bb033f2981b80ff5c6b227b73e",
          key: "example.json",
          last_modified: ~U[2024-08-26 07:06:49.000Z],
          owner: nil,
          size: 32,
          storage_class: "STANDARD"
        }

      assert [^expected_object | _] = objects
    end
  end

  describe "get_object/3: " do
    test "returns expected response" do
      assert {:ok, "Hello world!"} = Uppy.Storages.S3.get_object(@bucket, "example.txt")
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
      } = Uppy.Storages.S3.head_object(@bucket, "example.txt")
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
      } = Uppy.Storages.S3.presigned_url(@bucket, :post, "example.txt")
    end

    test "returns expected response for PUT request" do
      assert {
        :ok,
        %{
          expires_at: _,
          key: "example.txt",
          url: _
        }
      } = Uppy.Storages.S3.presigned_url(@bucket, :put, "example.txt")
    end
  end

  describe "put_object_copy/5: " do
    test "returns expected response" do
      assert {:ok, %{
        body: _,
        headers: _,
        status_code: 200
      }} =
        Uppy.Storages.S3.put_object_copy(
          @bucket,
          "example_copy.txt",
          @bucket,
          "example.txt"
        )
    end
  end

  describe "put_object/4: " do
    test "returns expected response" do
      assert {:ok, %{
        body: _,
        headers: _,
        status_code: 200
      }} =
        Uppy.Storages.S3.put_object(
          @bucket,
          "example_put_object.txt",
          "Hello World"
        )
    end
  end

  describe "delete_object/3: " do
    test "returns expected response" do
      assert {:ok, %{
        body: _,
        headers: _,
        status_code: 200
      }} =
        Uppy.Storages.S3.put_object(
          @bucket,
          "example_delete_object.txt",
          "Hello World"
        )

      assert {:ok, %{
        body: "",
        headers: _,
        status_code: 204
      }} =
        Uppy.Storages.S3.delete_object(
          @bucket,
          "example_delete_object.txt"
        )
    end
  end

  describe "multipart upload: " do
    test "can complete multipart upload" do
      assert {:ok, %{
        key: "multipart_example.test",
        bucket: "uppy-test",
        upload_id: upload_id
      }} = Uppy.Storages.S3.initiate_multipart_upload(@bucket, "multipart_example.test")

      expected_multipart_upload =
        %{
          key: "multipart_example.test",
          upload_id: upload_id
        }

      assert {:ok, %{
        bucket: "uppy-test",
        key_marker: "",
        upload_id_marker: "",
        uploads: uploads
      }} = Uppy.Storages.S3.list_multipart_uploads(@bucket)

      assert ^expected_multipart_upload = Enum.find(uploads, & &1.upload_id === upload_id)

      part_number = 1

      assert {:ok, %{
        key: "multipart_example.test",
        url: presigned_url,
        expires_at: _
      }} =
        Uppy.Storages.S3.presigned_url(
          @bucket,
          :put,
          "multipart_example.test",
          query_params: %{
            "uploadId" => upload_id,
            "partNumber" => part_number
          }
        )

      # part size needs to be at least 5MB
      payload =
        1_024 * 1_024 * 10
        |> :crypto.strong_rand_bytes()
        |> Base.encode64()

      assert {:ok, {body, response}} =
        Uppy.HTTP.put(presigned_url, payload, [], disable_json_encoding?: true)

      assert "" = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: "",
        headers: _,
        request: %Finch.Request{
          scheme: :https,
          host: _,
          port: 443,
          method: "PUT",
          path: "/uppy-test/multipart_example.test",
          headers: [],
          body: _,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert {:ok, [
        %{
          size: _,
          e_tag: part_e_tag,
          part_number: ^part_number
        }
      ]} = Uppy.Storages.S3.list_parts(@bucket, "multipart_example.test", upload_id)

      assert {:ok, %{
        bucket: "uppy-test",
        etag: _,
        key: "multipart_example.test",
        location: _
      }} =
        Uppy.Storages.S3.complete_multipart_upload(
          @bucket,
          "multipart_example.test",
          upload_id,
          [{part_number, part_e_tag}]
        )
    end

    test "can abort multipart upload" do
      assert {:ok, %{
        key: "multipart_example.test",
        bucket: "uppy-test",
        upload_id: upload_id
      }} = Uppy.Storages.S3.initiate_multipart_upload(@bucket, "multipart_example.test")

      expected_multipart_upload =
        %{
          key: "multipart_example.test",
          upload_id: upload_id
        }

      assert {:ok, %{
        bucket: "uppy-test",
        key_marker: "",
        upload_id_marker: "",
        uploads: uploads
      }} = Uppy.Storages.S3.list_multipart_uploads(@bucket)

      assert ^expected_multipart_upload = Enum.find(uploads, & &1.upload_id === upload_id)

      part_number = 1

      assert {:ok, %{
        key: "multipart_example.test",
        url: presigned_url,
        expires_at: _
      }} =
        Uppy.Storages.S3.presigned_url(
          @bucket,
          :put,
          "multipart_example.test",
          query_params: %{
            "uploadId" => upload_id,
            "partNumber" => part_number
          }
        )

      # part size needs to be at least 5MB
      payload =
        1_024 * 1_024 * 10
        |> :crypto.strong_rand_bytes()
        |> Base.encode64()

      assert {:ok, {body, response}} =
        Uppy.HTTP.put(presigned_url, payload, [], disable_json_encoding?: true)

      assert "" = body

      assert %Uppy.HTTP.Finch.Response{
        status: 200,
        body: "",
        headers: _,
        request: %Finch.Request{
          scheme: :https,
          host: _,
          port: 443,
          method: "PUT",
          path: "/uppy-test/multipart_example.test",
          headers: [],
          body: _,
          unix_socket: nil,
          private: %{}
        }
      } = response

      assert {:ok, [
        %{
          size: _,
          e_tag: _,
          part_number: ^part_number
        }
      ]} = Uppy.Storages.S3.list_parts(@bucket, "multipart_example.test", upload_id)

      assert {:ok, %{
        body: "",
        headers: _,
        status_code: 204
      }} = Uppy.Storages.S3.abort_multipart_upload(@bucket, "multipart_example.test", upload_id)
    end
  end
end
