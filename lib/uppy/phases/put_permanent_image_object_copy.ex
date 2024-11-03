defmodule Uppy.Phases.PutPermanentImageObjectCopy do
  @moduledoc """
  ...
  """

  alias Uppy.{
    ImageProcessor,
    Resolution
  }

  @behaviour Uppy.Phase

  @one_thousand_twenty_four 1_024

  @five_megabytes 5_242_880

  @impl true
  def run(
    %{
      state: :unresolved,
      context: context,
      bucket: bucket,
      value: schema_struct,
    } = resolution,
    opts
  ) do
    if opts[:image_processor_enabled] do
      cond do
        supported_image?(context.file_info, context.metadata, opts) === false ->
          {:ok, resolution}

        true ->
          with {:ok, response} <-
            ImageProcessor.put_result(
              bucket,
              context.destination_object,
              %{},
              schema_struct.key,
              opts
            ) do
            {:ok, Resolution.put_private(resolution, __MODULE__, %{
              image_processor: response
            })}
          end
      end
    else
      {:ok, resolution}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end

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
end
