defmodule Uppy.Thumbor do
  def put_result(adapter, bucket, image_uri, params, destination_object, options) do
    adapter.put_result(bucket, image_uri, params, destination_object, options)
  end
end
