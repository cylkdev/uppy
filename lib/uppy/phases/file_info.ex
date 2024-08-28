defmodule Uppy.Phases.FileInfo do
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

  @logger_prefix "Uppy.Phases.FileInfo"

  # Approximately 256 bytes is needed to detect the file type.
  @two_hundred_fifty_six_bytes 256

  @doc false
  @spec default_end_byte :: pos_integer()
  def default_end_byte, do: @two_hundred_fifty_six_bytes

  def run(
    %Uppy.Pipeline.Input{
      bucket: bucket,
      schema_data: schema_data,
      context: context
    } = input,
    options
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN", binding: binding())

    with {:ok, file_info} <-
      describe_object_chunk(bucket, schema_data.key, options) do
      {:ok, %{input | context: Map.put(context, :file_info, file_info)}}
    end
  end

  @doc """
  Returns the `mimetype`, `extension`, and `basename` detected from the file binary data.
  """
  def describe_object_chunk(bucket, object, options \\ []) do
    with {:ok, binary} <- download_chunk(bucket, object, options) do
      from_binary(binary)
    end
  end

  def download_chunk(bucket, object, options \\ []) do
    end_byte = end_byte!(options)

    with {:ok, {_start_byte, body}} <-
      Storage.get_chunk(bucket, object, 0, end_byte, options) do
      {:ok, body}
    end
  end

  def from_binary(binary) do
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
    options[:download_chunk_end_byte] || @two_hundred_fifty_six_bytes
  end
end
