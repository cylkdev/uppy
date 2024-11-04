defmodule Uppy.Phases.FileInfo do
  @moduledoc """
  ...
  """
  alias Uppy.{
    Resolution,
    Storage
  }

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.FileInfo"

  # Approximately 256 bytes is needed to detect the file type.
  @two_hundred_fifty_six_bytes 256

  @impl true
  def run(
    %{
      state: :unresolved,
      bucket: bucket,
      value: schema_struct,
    } = resolution,
    opts
  ) do
    Uppy.Utils.Logger.debug(@logger_prefix, "run | BEGIN | executing file info phase")

    case describe_object_chunk(bucket, schema_struct.key, opts) do
      {:ok, file_info} ->
        Uppy.Utils.Logger.debug(@logger_prefix, "run | OK | retrieved file info\n\n#{inspect(file_info, pretty: true)}")

        resolution =
          resolution
          |> Resolution.assign_context(:file_info, file_info)
          |> Resolution.put_private(__MODULE__, %{completed: true})

        {:ok, resolution}

      {:error, _} = error ->
        Uppy.Utils.Logger.debug(@logger_prefix, "run | ERROR | failed to get object file info\n\n#{inspect(error, pretty: true)}")

        {:ok, resolution}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end

  @doc """
  Returns the `mimetype`, `extension`, and `basename` detected from the file binary data.
  """
  def describe_object_chunk(bucket, object, opts) do
    start_byte = 0
    end_byte = end_byte!(opts)

    Uppy.Utils.Logger.debug(
      @logger_prefix,
      "describe_object_chunk | BEGIN | requesting bytes of object #{inspect(object)} " <>
      "| start_byte=#{inspect(start_byte)}, end_byte=#{inspect(end_byte)}"
    )

    with {:ok, {start_byte, body}} <-
      Storage.get_chunk(bucket, object, start_byte, end_byte, opts) do

      Uppy.Utils.Logger.debug(
        @logger_prefix,
        "describe_object_chunk | INFO | downloaded bytes of object " <>
        "| start_byte=#{inspect(start_byte)}, byte_size=#{byte_size(body)}"
      )

      case file_info(body) do
        {:ok, {base_extension, base_mimetype}} ->
          case ExImageInfo.info(body) do
            nil ->
              Uppy.Utils.Logger.debug(
                @logger_prefix,
                """
                describe_object_chunk | OK | detected file info

                extension: #{inspect(base_extension)}
                mimetype: #{inspect(base_mimetype)}
                """
              )

              {:ok, %{
                extension: base_extension,
                mimetype: base_mimetype
              }}

            {mimetype, width, height, variant_type}  ->
              Uppy.Utils.Logger.debug(
                @logger_prefix,
                """
                describe_object_chunk | OK | detected image info

                extension: #{inspect(base_extension)}
                mimetype: #{inspect(base_mimetype)}
                width: #{inspect(width)}
                height: #{inspect(height)}
                variant_type: #{inspect(variant_type)}
                """
              )

              {:ok, %{
                extension: base_extension,
                mimetype: mimetype,
                width: width,
                height: height,
                variant_type: variant_type
              }}

          end

      {:error, _} = error ->
        Uppy.Utils.Logger.warning(
          @logger_prefix,
          "describe_object_chunk | ERROR | failed to detect file info with error: #{inspect(error)}"
        )

        error
      end
    end
  end

  defp file_info(binary) do
    with {:ok, io} <- :file.open(binary, [:ram, :binary]) do
      FileType.from_io(io)
    end
  end

  defp end_byte!(opts) do
    opts[:file_info_end_byte] || @two_hundred_fifty_six_bytes
  end
end
