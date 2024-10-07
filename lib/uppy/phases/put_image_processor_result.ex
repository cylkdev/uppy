defmodule Uppy.Phases.PutImageProcessorResult do
  @moduledoc """
  ...
  """

  alias Uppy.{
    PathBuilder,
    Utils
  }

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.PutImageProcessorResult"

  @default_resource "uploads"

  @one_thousand_twenty_four 1_024

  @five_megabytes 5_242_880

  def run(
    %Uppy.Resolution{
      bucket: bucket,
      value: schema_data,
      context: context
    } = resolution,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    holder    = context.holder
    file_info = context.file_info
    metadata  = context.metadata

    cond do
      phase_completed?(context) ->
        Utils.Logger.debug(@logger_prefix, "skipped execution because destination object already exists")

        {:ok, resolution}

      supported_image?(file_info, metadata, opts) === false ->
        Utils.Logger.debug(@logger_prefix, "skipped execution because image not supported")

        {:ok, resolution}

      true ->
        Utils.Logger.debug(@logger_prefix, "copying optimized image result")

        with {:ok, destination_object} <-
          put_permanent_result(bucket, holder, schema_data, opts) do
          Utils.Logger.debug(@logger_prefix, "copied image to #{inspect(destination_object)}")

          {:ok, %{resolution | context: Map.put(context, :destination_object, destination_object)}}
        else
          error ->
            Utils.Logger.debug(@logger_prefix, "failed to process image")

            error
        end
    end
  end

  defp phase_completed?(%{destination_object: _}), do: true
  defp phase_completed?(_), do: false

  defp width_and_height_less_than_max?(%{width: width, height: height}, opts) do
    max_image_width = opts[:max_image_width] || @one_thousand_twenty_four
    max_image_height = opts[:max_image_height] || @one_thousand_twenty_four

    (width <= max_image_width) and (height <= max_image_height)
  end

  defp has_width_and_height?(%{width: _, height: _}), do: true
  defp has_width_and_height?(_), do: false

  defp image_size_less_than_max?(%{content_length: content_length}, opts) do
    max_image_size = opts[:max_image_size] || @five_megabytes

    content_length <= max_image_size
  end

  defp supported_image?(file_info, metadata, opts) do
    has_width_and_height?(file_info) and
    width_and_height_less_than_max?(file_info, opts) and
    image_size_less_than_max?(metadata, opts)
  end

  def put_permanent_result(bucket, %_{} = holder, %_{} = schema_data, opts) do
    holder_id = Uppy.Holder.fetch_id!(holder, opts)
    resource = resource!(opts)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key

    destination_object =
      PathBuilder.permanent_path(
        %{
          id: holder_id,
          resource: resource,
          basename: basename
        },
        opts
      )

    params = opts[:image_processor_parameters] || %{}

    with {:ok, _} <-
      Uppy.ImageProcessor.put_result(
        bucket,
        source_object,
        params,
        destination_object,
        opts
      ) do
      {:ok, destination_object}
    end
  end

  defp resource!(opts) do
    with nil <- Keyword.get(opts, :resource, @default_resource) do
      raise "option `:resource` cannot be `nil` for phase #{__MODULE__}"
    end
  end
end
