defmodule Uppy.Phases.UpdateSchemaMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{
    Action,
    Utils
  }

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
          bucket: bucket,
          schema: schema,
          schema_data: schema_data,
          context: %{
            file_info: file_info,
            metadata: metadata
          }
        } = input,
        options
      ) do
    Utils.Logger.debug(@logger_prefix, "RUN BEGIN", binding: binding())

    with {:ok, schema_data} <-
      update_metadata(schema, schema_data, file_info, metadata, options) do
      {:ok, %{input | schema_data: schema_data}}
    end
  end

  def update_metadata(schema, schema_data, file_info, metadata, options) do
    Action.update(
      schema,
      schema_data,
      %{
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
    String.replace(Path.basename(path), Path.extname(path), "") <> extension
  end
end
