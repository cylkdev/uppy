defmodule Uppy.Pipelines.Phases.UpdateSchemaMetadata do
  @moduledoc """
  Retrieves the metadata of an object from storage and updates the database record.

  The following fields are updated:

  - `:e_tag`
  - `:content_type`
  - `:content_length`
  - `:last_modified`
  """
  alias Uppy.{
    Actions,
    Pipelines.Input,
    Pipelines.Phases,
    Storages,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipelines.Phases.UpdateSchemaMetadata"

  @impl Uppy.Adapter.Pipeline.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Pipeline.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipelines.Input{
          bucket: bucket,
          schema: schema,
          value: schema_data,
          options: runtime_options
        } = input,
        phase_options
      ) do
    Utils.Logger.debug(
      @logger_prefix,
      "run schema=#{inspect(schema)}, id=#{inspect(schema_data.id)}"
    )

    options = Keyword.merge(phase_options, runtime_options)

    with {:ok, update_params} <-
           build_update_params(input, bucket, schema_data, options),
         {:ok, schema_data} <-
           Actions.update(schema, schema_data, update_params, options) do
      Utils.Logger.debug(
        @logger_prefix,
        "updated schema data:\n\n#{inspect(schema_data, pretty: true)}"
      )

      {:ok, Input.put_value(input, schema_data)}
    end
  end

  # merge metadata from the phase `Uppy.Pipelines.Phases.ObjectMetadata` and storage.
  # the file info from the phase takes priority.
  defp build_update_params(input, bucket, %{key: object, filename: filename}, options) do
    Utils.Logger.debug(@logger_prefix, "build_update_params - building update params")

    case Phases.ObjectMetadata.find_private(input) do
      {:ok, file_info} ->
        Utils.Logger.debug(@logger_prefix, "build_update_params - object metadata state found")

        with {:ok, metadata} <- Storages.head_object(bucket, object, options) do
          {:ok,
           %{
             filename: filename(filename, file_info.extension),
             e_tag: metadata.e_tag,
             content_type: file_info.content_type,
             content_length: metadata.content_length,
             last_modified: metadata.last_modified
           }}
        end

      {:error, _} ->
        Utils.Logger.debug(
          @logger_prefix,
          "build_update_params - object metadata state not found, did you forget `Uppy.Pipelines.Phases.ObjectMetadata`?"
        )

        with {:ok, metadata} <- Storages.head_object(bucket, object, options) do
          {:ok,
           %{
             filename: filename,
             e_tag: metadata.e_tag,
             content_type: metadata.content_type,
             content_length: metadata.content_length,
             last_modified: metadata.last_modified
           }}
        end
    end
  end

  defp filename(path, extension) do
    String.replace(Path.basename(path), Path.extname(path), "") <> extension
  end
end
