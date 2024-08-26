defmodule Uppy.Storages.S3Test do
  use ExUnit.Case, async: true

  @bucket "uppy-test"

  describe "download_chunk_stream/4: " do
    test "returns expected response" do
      assert {:ok, stream} = Uppy.Storages.S3.download_chunk_stream(@bucket, "example.txt", 4)

      assert "Hello world!" =
        stream
        |> Task.async_stream(fn %{start_byte: start_byte, end_byte: end_byte} ->
          Uppy.Storages.S3.get_chunk!(@bucket, "example.txt", start_byte, end_byte, disable_json_decoding?: true)
        end)
        |> Enum.to_list()
    end
  end

  describe "get_chunk/5: " do
    test "returns expected response" do
      assert {:ok, "Hello"} = Uppy.Storages.S3.get_chunk(@bucket, "example.txt", 0, 4)
    end
  end

  describe "list_objects/3: " do
    test "returns expected response" do
      assert {:ok, objects} = Uppy.Storages.S3.list_objects(@bucket)

      assert [
        %{
          owner: nil,
          size: 12,
          key: "example.txt",
          last_modified: _object_last_modified,
          e_tag: _object_e_tag,
          storage_class: "STANDARD"
        }
      ] = objects
    end
  end
end
