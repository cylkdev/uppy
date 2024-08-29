defmodule Uppy.ImageProcessor do
  @moduledoc """
  ...
  """

  @default_options [
    image_processor: [sandbox: Mix.env() === :test]
  ]

  @default_adapter Thumbor

  def put_result(
    bucket,
    source_object,
    params,
    destination_object,
    options \\ []
  ) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:image_processor][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_result_response(bucket, source_object, params, destination_object, options)
    else
      adapter!(options).put_result(bucket, source_object, params, destination_object, options)
    end
  end

  defp adapter!(options) do
    options[:image_processor_adapter] || @default_adapter
  end

  if Mix.env() === :test do
    defdelegate sandbox_put_result_response(bucket, source_object, params, destination_object, options),
      to: Uppy.Support.ImageProcessorSandbox,
      as: :put_result_response

    defdelegate sandbox_disabled?, to: Uppy.Support.ImageProcessorSandbox
  else
    defp sandbox_put_result_response(bucket, source_object, params, destination_object, options) do
      raise """
      Cannot use ImageProcessorSandbox outside of test

      bucket: #{inspect(bucket)}
      source_object: #{inspect(source_object)}
      destination_object: #{inspect(destination_object)}
      params: #{inspect(params)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
