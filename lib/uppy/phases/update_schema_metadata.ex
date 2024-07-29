defmodule Uppy.Phase.UpdateSchemaMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{
    Action,
    Storage,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Phase.UpdateSchemaMetadata"

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

    update_params =
      case Map.get(value, :file_info) do
        nil -> %{}
        file_info -> %{content_type: file_info.mimetype, extension: file_info.extension}
      end

    update_metadata(bucket, schema, schema_data, update_params, options)
  end


  def update_metadata(bucket, schema, %_{filename: filename, key: object} = schema_data, update_params, options) do
    Utils.Logger.debug(@logger_prefix, "update_metadata BEGIN", binding: binding())

    filename =
      case update_params[:extension] do
        nil -> update_params[:filename] || filename
        extension -> filename(object, extension)
      end

    with {:ok, metadata} <- Storage.head_object(bucket, object, options) do
      Action.update(
        schema,
        schema_data,
        %{
          filename: filename,
          e_tag: metadata.e_tag,
          content_type: update_params[:content_type] || metadata.content_type,
          content_length: metadata.content_length,
          last_modified: metadata.last_modified
        },
        options
      )
    end
  end

  def update_metadata(bucket, schema, find_params, update_params, options) do
    Utils.Logger.debug(@logger_prefix, "update_metadata BEGIN", binding: binding())

    with {:ok, schema_data} <- Action.find(schema, find_params, options) do
      update_metadata(bucket, schema, schema_data, update_params, options)
    end
  end

  defp filename(path, extension) do
    String.replace(Path.basename(path), Path.extname(path), "") <> extension
  end
end
