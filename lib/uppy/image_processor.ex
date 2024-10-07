defmodule Uppy.ImageProcessor do
  @moduledoc """
  ...
  """

  @default_opts [
    image_processor: [sandbox: Mix.env() === :test]
  ]

  @default_adapter Thumbor

  def put_result(
    bucket,
    source_object,
    params,
    destination_object,
    opts \\ []
  ) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:image_processor][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_result_response(bucket, source_object, params, destination_object, opts)
    else
      adapter!(opts).put_result(bucket, source_object, params, destination_object, opts)
    end
  end

  defp adapter!(opts) do
    opts[:image_processor_adapter] || @default_adapter
  end

  if Mix.env() === :test do
    defdelegate sandbox_put_result_response(bucket, source_object, params, destination_object, opts),
      to: Uppy.Support.ImageProcessorSandbox,
      as: :put_result_response

    defdelegate sandbox_disabled?, to: Uppy.Support.ImageProcessorSandbox
  else
    defp sandbox_put_result_response(bucket, source_object, params, destination_object, opts) do
      raise """
      Cannot use ImageProcessorSandbox outside of test

      bucket: #{inspect(bucket)}
      source_object: #{inspect(source_object)}
      destination_object: #{inspect(destination_object)}
      params: #{inspect(params)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
