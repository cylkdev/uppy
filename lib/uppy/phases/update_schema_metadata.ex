defmodule Uppy.Phases.UpdateSchemaMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{DBAction, Utils}

  @type resolution :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type opts :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.UpdateSchemaMetadata"

  def run(
    %Uppy.Resolution{
      query: query,
      value: schema_data,
      context: context
    } = resolution,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    file_info           = context.file_info
    metadata            = context.metadata
    destination_object  = context.destination_object

    with {:ok, schema_data} <-
      update_metadata(
        query,
        schema_data,
        destination_object,
        file_info,
        metadata,
        opts
      ) do
        Utils.Logger.debug(@logger_prefix, "Updated record metadata")

      {:ok, %{resolution | value: schema_data}}
    end
  end

  def update_metadata(
    query,
    schema_data,
    destination_object,
    file_info,
    metadata,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "updating record metadata")

    DBAction.update(
      query,
      schema_data,
      %{
        key: destination_object,
        filename: filename(schema_data.key, file_info.extension),
        e_tag: metadata.e_tag,
        content_type: file_info.mimetype,
        content_length: metadata.content_length,
        last_modified: metadata.last_modified
      },
      opts
    )
  end

  defp filename(path, extension) do
    basename = Path.basename(path)
    extname = Path.extname(path)

    basename_without_extension = String.replace(basename, extname, "")

    "#{basename_without_extension}.#{extension}"
  end
end
