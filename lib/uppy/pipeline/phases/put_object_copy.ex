defmodule Uppy.Pipeline.Phases.PutObjectCopy do
  alias Uppy.TemporaryScope

  alias Uppy.{
    Actions,
    Core,
    Error,
    PermanentScope,
    Storage
  }

  def run(
        %{
          value: schema_data,
          context: %{
            bucket: bucket,
            schema: schema,
            resource_name: resource_name,
            action_adapter: action_adapter,
            storage_adapter: storage_adapter,
            permanent_scope_adapter: permanent_scope_adapter,
            temporary_scope_adapter: temporary_scope_adapter
          },
          private: private
        } = input,
        options
      ) do
    holder = Map.fetch!(input, :holder)

    permanent_object_params =
      build_permanent_object_params(
        permanent_scope_adapter,
        resource_name,
        schema_data,
        holder,
        options
      )

    with :ok <- ensure_temporary_upload(temporary_scope_adapter, schema_data),
         {:ok, payload} <-
           put_object_copy_and_update_metadata(
             bucket,
             storage_adapter,
             schema,
             schema_data,
             permanent_object_params.destination_object,
             action_adapter,
             options
           ) do
      private = [{__MODULE__, Map.merge(permanent_object_params, payload)} | private]

      {:ok, %{input | private: private, value: payload.schema_data}}
    end
  end

  defp ensure_temporary_upload(temporary_scope_adapter, schema_data) do
    if TemporaryScope.path?(temporary_scope_adapter, schema_data.key) do
      :ok
    else
      {:error, Error.call(:forbidden, "not a temporary upload", %{schema_data: schema_data})}
    end
  end

  def put_object_copy_and_update_metadata(
        bucket,
        storage_adapter,
        schema,
        schema_data,
        destination_object,
        action_adapter,
        options
      ) do
    with {:ok, metadata} <-
           put_object_copy(
             storage_adapter,
             bucket,
             destination_object,
             schema_data.key,
             options
           ),
         {:ok, schema_data} <-
           update_metadata(
             action_adapter,
             schema,
             schema_data,
             destination_object,
             metadata,
             options
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def put_object_copy(storage_adapter, bucket, destination_object, source_object, options) do
    with {:ok, _} <-
           Storage.put_object_copy(
             storage_adapter,
             bucket,
             destination_object,
             bucket,
             source_object,
             options
           ) do
      Storage.head_object(
        storage_adapter,
        bucket,
        destination_object,
        options
      )
    end
  end

  def build_permanent_object_params(
        permanent_scope_adapter,
        resource_name,
        schema_data,
        holder,
        options
      ) do
    partition_id = partition_id(holder, options)

    basename =
      Core.basename(
        schema_data.unique_identifier,
        schema_data.filename
      )

    source_object = schema_data.key

    destination_object =
      PermanentScope.prefix(
        permanent_scope_adapter,
        partition_id,
        resource_name,
        basename
      )

    %{
      basename: basename,
      source_object: source_object,
      destination_object: destination_object,
      partition_id: partition_id
    }
  end

  def update_metadata(action_adapter, schema, schema_data, key, metadata, options) do
    Actions.update(
      action_adapter,
      schema,
      schema_data,
      %{
        key: key,
        e_tag: metadata.e_tag,
        content_type: metadata.content_type,
        content_length: metadata.content_length,
        last_modified: metadata.last_modified
      },
      options
    )
  end

  defp partition_id(holder, options) do
    partition_key = Keyword.get(options, :partition_key, :company_id)

    case Map.fetch!(holder, partition_key) do
      nil ->
        raise "Partition key #{inspect(partition_key)} value cannot be nil.\n\ngot:\n\n#{inspect(holder, pretty: true)}"

      value ->
        value
    end
  end
end
