defmodule Uppy.Pipelines.Phases.MIMEType do
  @moduledoc """
  ...
  """
  alias Uppy.{
    Storages,
    Utils
  }
  alias Uppy.Pipelines.Input

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipelines.Phases.MIMEType"

  # ~256 bytes is needed to detect the file type
  @two_hundred_fifty_six_bytes 256

  def run(
    %Uppy.Pipelines.Input{
      bucket: bucket,
      schema: schema,
      value: schema_data,
      options: runtime_options
    } = input,
    phase_options
  ) do
    Utils.Logger.debug(@logger_prefix, "run schema=#{inspect(schema)}, id=#{inspect(schema_data.id)}")
    Utils.Logger.debug(@logger_prefix, "loading holder")

    options = Keyword.merge(phase_options, runtime_options)

    object = schema_data.key

    with {:ok, metadata} <- describe_object(bucket, object, options) do
      {:ok, Input.put_private(input, __MODULE__, metadata)}
    end
  end

  @doc """
  Returns the `content_type`, `extension`, and `basename` detected from
  the file binary data.

  ### Examples

      iex> Uppy.Pipelines.Phases.MIMEType.describe_object("bucket", "object")
  """
  def describe_object(bucket, object, options \\ []) do
    Utils.Logger.debug(@logger_prefix, "describe_object bucket=#{inspect(bucket)}, object=#{inspect(object)}")

    with {:ok, data} <- download_head(bucket, object, options),
      {:ok, file} <- :file.open(data, [:ram, :binary]) do
      # TODO: replace filetype
      case FileType.from_io(file) do
        {:error, :unrecognized} ->
          extension = Path.extname(object)
          mimetype = :mimerl.filename(object)

          Utils.Logger.debug(@logger_prefix, "describe_object OK mimetype=#{inspect(mimetype)}, extension=#{inspect(extension)}")

          {:ok, %{extension: extension, content_type: mimetype}}

        {:ok, {extension, mimetype}} ->
          Utils.Logger.debug(@logger_prefix, "describe_object OK mimetype=#{inspect(mimetype)}, extension=#{inspect(extension)}")

          {:ok, %{extension: extension, content_type: mimetype}}
      end
    end
  end

  def download_head(bucket, object, options \\ []) do
    start_byte = 0
    end_byte = end_byte!(options)

    Utils.Logger.debug(@logger_prefix, "download_head bucket=#{inspect(bucket)}, object=#{inspect(object)}, start_byte=#{inspect(start_byte)}, end_byte=#{inspect(end_byte)}")

    with {:ok, {_start_byte, body}} <-
      Storages.get_chunk(bucket, object, start_byte, end_byte, options) do
      Utils.Logger.debug(@logger_prefix, "download_head OK byte_size=#{:erlang.byte_size(body)} bytes")

      {:ok, body}
    end
  end

  defp end_byte!(options) do
    case options[:pipeline][:mimetype][:end_byte_size] do
      nil -> @two_hundred_fifty_six_bytes
      end_byte when end_byte <= @two_hundred_fifty_six_bytes -> end_byte
      term -> raise "Expected option `:end_byte` to be between 0..#{@two_hundred_fifty_six_bytes}, got: #{inspect(term)}"
    end
  end
end
