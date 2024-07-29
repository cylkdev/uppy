defmodule Uppy.Phase.FileInfo do
  alias Uppy.{
    Error,
    Storage,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phase.FileInfo"

  # Approximately 256 bytes is needed to detect the file type.
  @two_hundred_fifty_six_bytes 256

  def run(
        %Uppy.Pipeline.Input{
          bucket: bucket,
          schema: schema,
          value: %{schema_data: schema_data} = value,
          options: runtime_options
        } = input,
        phase_options
      ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN", binding: binding())

    options = Keyword.merge(phase_options, runtime_options)

    with {:ok, metadata} <- describe_object_chunk(bucket, schema_data.key, options) do
      {:ok, %{input | value: Map.put(value, :file_info, metadata)}}
    end
  end

  @doc """
  Returns the `mimetype`, `extension`, and `basename` detected from the file binary data.
  """
  def describe_object_chunk(bucket, object, options \\ []) do
    Utils.Logger.debug(@logger_prefix, "describe_object_chunk BEGIN", binding: binding())

    with {:ok, binary} <- download_chunk(bucket, object, options) do
      from_binary(binary)
    end
  end

  def download_chunk(bucket, object, options \\ []) do
    Utils.Logger.debug(@logger_prefix, "download_chunk BEGIN", binding: binding())

    end_byte = end_byte!(options)

    with {:ok, {_start_byte, body}} <-
           Storage.get_chunk(bucket, object, 0, end_byte, options) do
      {:ok, body}
    end
  end

  def from_binary(binary) do
    Utils.Logger.debug(@logger_prefix, "from_binary BEGIN")

    with {:ok, file_info} <- file_info(binary) do
      case image_info(binary) do
        nil -> {:ok, file_info}
        image_info -> {:ok, Map.merge(file_info, image_info)}
      end
    end
  end

  defp file_info(binary) do
    with {:ok, io} <- :file.open(binary, [:ram, :binary]) do
      case FileType.from_io(io) do
        {:error, :unrecognized} -> {:error, Error.forbidden("unrecognized file format")}
        {:ok, {extension, mimetype}} -> {:ok, %{extension: extension, mimetype: mimetype}}
      end
    end
  end

  defp image_info(binary) do
    with {mimetype, width, height, variant_type} <- ExImageInfo.info(binary) do
      %{
        mimetype: mimetype,
        width: width,
        height: height,
        variant_type: variant_type
      }
    end
  end

  defp end_byte!(options) do
    options[:pipeline][:object_metadata][:end_byte] || @two_hundred_fifty_six_bytes
  end
end
