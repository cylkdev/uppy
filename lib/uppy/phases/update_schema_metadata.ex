defmodule Uppy.Phases.UpdateSchemaMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{Action, Utils}

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.UpdateSchemaMetadata"

  def run(
    %Uppy.Pipeline.Input{
      schema: schema,
      schema_data: schema_data,
      context: context
    } = input,
    options
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    file_info = context.file_info
    metadata = context.metadata
    destination_object = context.destination_object

    with {:ok, schema_data} <-
      update_metadata(
        schema,
        schema_data,
        destination_object,
        file_info,
        metadata,
        options
      ) do
        Utils.Logger.debug(@logger_prefix, "Updated schema data:\n\n#{inspect(schema_data, pretty: true)}")

      {:ok, %{input | schema_data: schema_data}}
    end
  end

  def update_metadata(
    schema,
    schema_data,
    destination_object,
    file_info,
    metadata,
    options
  ) do
    Utils.Logger.debug(
      @logger_prefix,
      """
      Updating schema data:

      schema:

      #{inspect(schema)}

      schema data:

      #{inspect(schema_data, pretty: true)}

      destination object:

      #{inspect(destination_object, pretty: true)}

      file info:

      #{inspect(file_info, pretty: true)}

      storage metadata:

      #{inspect(metadata, pretty: true)}
      """
    )

    Action.update(
      schema,
      schema_data,
      %{
        key: destination_object,
        filename: filename(schema_data.key, file_info.extension),
        e_tag: metadata.e_tag,
        content_type: file_info.mimetype,
        content_length: metadata.content_length,
        last_modified: metadata.last_modified
      },
      options
    )
  end

  defp filename(path, extension) do
    basename = Path.basename(path)
    extname = Path.extname(path)

    basename_without_extension = String.replace(basename, extname, "")

    "#{basename_without_extension}.#{extension}"
  end
end
