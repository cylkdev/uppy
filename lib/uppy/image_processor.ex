defmodule Uppy.ImageProcessor do
  @moduledoc """
  ...
  """

  @default_adapter Uppy.ImageProcessors.Thumbor

  @callback put_result(
              bucket :: binary(),
              destination_object :: binary(),
              params :: map(),
              source_object :: binary(),
              opts :: keyword()
            ) :: {:ok, term(), :error, term()}

  def put_result(bucket, destination_object, params, source_object, opts) do
    adapter!(opts).put_result(bucket, destination_object, params, source_object, opts)
  end

  defp adapter!(opts) do
    opts[:image_processor_adapter] || @default_adapter
  end
end
