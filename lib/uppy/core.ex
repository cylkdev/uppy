defmodule Uppy.Core do
  @moduledoc """

  ### Definitions

  This section provides information on terminology used through the documentation.

  #### Temporary Object Keys

  A temporary object key is a string considered in the "temporary path". The "temporary path" is the
  location/folder in a `bucket` where users attempt to upload objects to. The objects uploaded to
  this path are considered temporary as they are not expected to be persisted until the object is
  moved to the "permanent path" and the database record is updated to reflect the new location and
  metadata of the object. These object keys are managed the temporary object key adapter`. See the
  `Uppy.Adapter.TemporaryObjectKey` module documentation for more information.

  > Note: Objects uploaded to the temporary path can end in up incomplete state that cannot be
  > recovered from. It is recommended to use a lifecycle rule or chron job to garbage collect objects
  > that have not been completed for some time.

  #### Permanent Object Keys

  A permanent object key is a string considered in the "permanent path". The "permanent path" is the
  location/folder in a`bucket` where objects are persisted. These object keys are managed the
  temporary object key adapter`. See the `Uppy.Adapter.TemporaryObjectKey` module documentation for
  more information.
  """

  alias Uppy.{
    Actions,
    Error,
    PermanentObjectKeys,
    Pipelines,
    Schedulers,
    Storages,
    TemporaryObjectKeys,
    Utils
  }

  @logger_prefix "Uppy.Core"

  @default_hash_size 32
  @one_hour_seconds 3_600

  @doc """
  Returns a string in the format of `<unique_identifier>-<path>`.

  ### Examples

      iex> Uppy.Core.basename("unique_identifier", "path")
      "unique_identifier-path"
  """
  def basename(unique_identifier, path) do
    "#{unique_identifier}-#{path}"
  end

  @doc """
  Returns a unique identifier string.

  ### Examples

      iex> Uppy.Core.generate_unique_identifier()
  """
  def generate_unique_identifier(options \\ []) do
    byte_size = Keyword.get(options, :unique_identifier_byte_size, @default_hash_size)

    Utils.generate_unique_identifier(byte_size)
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_multipart_upload(YourSchema, %{id: 1})
  """
  def find_permanent_multipart_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- find_permanent_upload(schema, params, options) do
      check_if_multipart_upload(schema_data, options)
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_multipart_upload(YourSchema, %{id: 1})
  """
  def find_completed_multipart_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- find_completed_upload(schema, params, options) do
      check_if_multipart_upload(schema_data, options)
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_multipart_upload(YourSchema, %{id: 1})
  """
  def find_temporary_multipart_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- find_temporary_upload(schema, params, options) do
      check_if_multipart_upload(schema_data, options)
    end
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata retrieved
  from the function `&Storages.complete_multipart_upload/6`.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

  ### Examples

      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, nil, prefix: "prefix")
      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def find_parts(
        bucket,
        schema,
        %schema_data_module{} = schema_data,
        nil_or_next_part_number_marker,
        options
      )
      when schema === schema_data_module do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_multipart_upload(schema_data, options),
         {:ok, parts} <-
           Storages.list_parts(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             nil_or_next_part_number_marker,
             options
           ) do
      {:ok,
       %{
         parts: parts,
         schema_data: schema_data
       }}
    end
  end

  def find_parts(bucket, schema, params, nil_or_next_part_number_marker, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      find_parts(bucket, schema, schema_data, nil_or_next_part_number_marker, options)
    end
  end

  def find_parts(
        bucket,
        schema,
        params_or_schema_data,
        nil_or_next_part_number_marker
      ) do
    find_parts(
      bucket,
      schema,
      params_or_schema_data,
      nil_or_next_part_number_marker,
      []
    )
  end

  def find_parts(
        bucket,
        schema,
        params_or_schema_data
      ) do
    find_parts(
      bucket,
      schema,
      params_or_schema_data,
      nil
    )
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata retrieved
  from the function `&Storages.complete_multipart_upload/6`.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

  ### Examples

      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1, prefix: "prefix")
      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1)
      iex> Uppy.Core.presigned_part("bucket", "unique_id", YourSchema, %{id: 1}, 1)
  """
  def presigned_part(bucket, _schema, %_{} = schema_data, part_number, options) do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_multipart_upload(schema_data, options),
         {:ok, presigned_part} <-
           Storages.presigned_part_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             part_number,
             options
           ) do
      {:ok,
       %{
         presigned_part: presigned_part,
         schema_data: schema_data
       }}
    end
  end

  def presigned_part(bucket, schema, params, part_number, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      presigned_part(bucket, schema, schema_data, part_number, options)
    end
  end

  def presigned_part(bucket, schema, params_or_schema_data, part_number) do
    presigned_part(bucket, schema, params_or_schema_data, part_number, [])
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata returned
  from the storage `&Storages.complete_multipart_upload/6` function.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

  ### Examples

      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}], prefix: "prefix")
      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}])
      iex> Uppy.Core.complete_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1}, [{1, "e_tag"}])
  """
  def complete_multipart_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        %_{} = schema_data,
        update_params,
        parts,
        options
      ) do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_multipart_upload(schema_data, options),
         {:ok, metadata} <-
           head_completed_multipart_upload(
             bucket,
             schema_data,
             parts,
             options
           ) do
      update_params = Map.put(update_params, :e_tag, metadata.e_tag)

      operation = fn ->
        with {:ok, schema_data} <- Actions.update(schema, schema_data, update_params, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_run_pipeline(
                     pipeline_module,
                     bucket,
                     resource_name,
                     schema,
                     schema_data.id,
                     options[:schedule][:run_pipeline],
                     options
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 schema_data: schema_data,
                 jobs: %{run_pipeline: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               schema_data: schema_data
             }}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def complete_multipart_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        find_params,
        update_params,
        parts,
        options
      ) do
    with {:ok, schema_data} <- Actions.find(schema, find_params, options) do
      complete_multipart_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        schema_data,
        update_params,
        parts,
        options
      )
    end
  end

  def complete_multipart_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        find_params_or_schema_data,
        update_params,
        parts
      ) do
    complete_multipart_upload(
      bucket,
      resource_name,
      pipeline_module,
      schema,
      find_params_or_schema_data,
      update_params,
      parts,
      []
    )
  end

  defp head_completed_multipart_upload(
         bucket,
         schema_data,
         parts,
         options
       ) do
    case Storages.complete_multipart_upload(
           bucket,
           schema_data.key,
           schema_data.upload_id,
           parts,
           options
         ) do
      {:ok, _} -> Storages.head_object(bucket, schema_data.key, options)
      {:error, %{code: :not_found}} -> Storages.head_object(bucket, schema_data.key, options)
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches a temporary upload database record by params, aborts the multipart upload and deletes the record.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def abort_multipart_upload(bucket, schema, %_{} = schema_data, options) do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_multipart_upload(schema_data, options),
         {:ok, nil_or_metadata} <-
           handle_abort_multipart_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             options
           ) do
      payload =
        if is_nil(nil_or_metadata) do
          %{schema_data: schema_data}
        else
          %{metadata: nil_or_metadata, schema_data: schema_data}
        end

      operation = fn ->
        with {:ok, schema_data} <- Actions.delete(schema_data, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_delete_object_if_upload_not_found(
                     bucket,
                     schema,
                     schema_data.key,
                     options[:schedule][:delete_object_if_upload_not_found] || @one_hour_seconds,
                     options
                   ) do
              {:ok, Map.put(payload, :jobs, %{delete_object_if_upload_not_found: job})}
            end
          else
            {:ok, payload}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def abort_multipart_upload(bucket, schema, params, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      abort_multipart_upload(bucket, schema, schema_data, options)
    end
  end

  def abort_multipart_upload(bucket, schema, params_or_schema_data) do
    abort_multipart_upload(bucket, schema, params_or_schema_data, [])
  end

  defp handle_abort_multipart_upload(bucket, key, upload_id, options) do
    case Storages.abort_multipart_upload(bucket, key, upload_id, options) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, %{code: :not_found}} -> {:ok, nil}
      {:error, _} = error -> error
    end
  end

  @doc """
  Initiates a multipart upload and creates a database record.

  The process of starting an upload is as follows:

      1. A unique identifier is generated and put into the `params` key `:unique_identifier`
        if the key is not set.

      2. A `basename` string is created using the `unique_identifier` and `filename`.

      3. A `key` is generated for a temporary object by the `temporary_object_key_adapter` given
        the `partition_id` and `basename`.

      4. The `key` generated in the previous step is signed by the `storage_adapter`.

      5. A multipart upload is initiated for the `key`.

      6. A database record is created for the temporary upload and the keys `:unique_identifier`,
        `filename`, and `:key` are set in the `params` map (These values are created in the
        previous steps).

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_multipart_upload(bucket, partition_id, schema, params, options)
      when is_integer(partition_id) do
    start_multipart_upload(bucket, Integer.to_string(partition_id), schema, params, options)
  end

  def start_multipart_upload(bucket, partition_id, schema, params, options)
      when is_binary(partition_id) do
    filename = params.filename
    unique_identifier = maybe_generate_unique_identifier(params[:unique_identifier], options)
    basename = basename(unique_identifier, filename)

    key = TemporaryObjectKeys.prefix(partition_id, basename, options)

    with {:ok, multipart_upload} <-
           Storages.initiate_multipart_upload(bucket, key, options) do
      params =
        Map.merge(params, %{
          upload_id: multipart_upload.upload_id,
          unique_identifier: unique_identifier,
          filename: filename,
          key: key
        })

      operation = fn ->
        with {:ok, schema_data} <- Actions.create(schema, params, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_abort_multipart_upload(
                     bucket,
                     schema,
                     schema_data.id,
                     options[:schedule][:abort_multipart_upload] || @one_hour_seconds,
                     options
                   ) do
              {:ok,
               %{
                 unique_identifier: unique_identifier,
                 basename: basename,
                 key: key,
                 multipart_upload: multipart_upload,
                 schema_data: schema_data,
                 jobs: %{abort_multipart_upload: job}
               }}
            end
          else
            {:ok,
             %{
               unique_identifier: unique_identifier,
               basename: basename,
               key: key,
               multipart_upload: multipart_upload,
               schema_data: schema_data
             }}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def start_multipart_upload(bucket, partition_id, schema, params) do
    start_multipart_upload(bucket, partition_id, schema, params, [])
  end

  @doc """
  Executes a list of phases on a given database record.

  The first phase in the pipeline is given the `input` argument specified to this function. The `input` is
  expected to be a `map` that contains the specified fields specified below.

  The required input fields are:

      * `bucket` - The name of the bucket.

      * `resource_name` - The name of the resource being uploaded to the bucket as a string, for eg. "avatars".

      * `schema` - The `Ecto.Schema` module.

      * `schema_data` - A `schema` named struct. This is the database record for the upload.

      * `options` - A keyword list of runtime options.

  See the `Uppy.Pipeline` module documentation for more information on the pipeline.
  """
  def run_pipeline(pipeline_module, bucket, resource_name, schema, params_or_schema_data, options)
      when is_atom(pipeline_module) do
    pipeline_module
    |> Pipelines.pipeline()
    |> run_pipeline(bucket, resource_name, schema, params_or_schema_data, options)
  end

  def run_pipeline(pipeline, bucket, resource_name, schema, %_{} = schema_data, options) do
    {schema, nil_or_source} = ensure_schema_source(schema)

    context = Keyword.get(options, :context, %{})

    input = %Uppy.Pipelines.Input{
      bucket: bucket,
      resource_name: resource_name,
      schema: schema,
      source: nil_or_source,
      schema_data: schema_data,
      context: context,
      options: options
    }

    with {:ok, output, executed_phases} <- Pipelines.run(input, pipeline) do
      {:ok, {output, executed_phases}}
    end
  end

  def run_pipeline(pipeline, bucket, resource_name, schema, params, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      run_pipeline(pipeline, bucket, resource_name, schema, schema_data, options)
    end
  end

  def run_pipeline(
        pipeline_module_or_pipeline,
        bucket,
        resource_name,
        schema,
        params_or_schema_data
      ) do
    run_pipeline(
      pipeline_module_or_pipeline,
      bucket,
      resource_name,
      schema,
      params_or_schema_data,
      []
    )
  end

  defp ensure_schema_source({schema, source}), do: {schema, source}
  defp ensure_schema_source(schema), do: {schema, nil}

  @doc """
  Deletes the object specified by `key` from storage if the database record does not exist.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

  ### Examples

      iex> Uppy.Core.delete_object_if_upload_not_found("bucket", {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.delete_object_if_upload_not_found("bucket", {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.delete_object_if_upload_not_found("bucket", YourSchema, %{id: 1})
  """
  def delete_object_if_upload_not_found(bucket, schema, key, options \\ []) do
    with :ok <- validate_not_found(schema, %{key: key}, options),
         {:ok, _} <- Storages.head_object(bucket, key, options),
         {:ok, _} <- Storages.delete_object(bucket, key, options) do
      :ok
    else
      {:error, %{code: :not_found}} -> :ok
      error -> error
    end
  end

  defp validate_not_found(schema, params, options) do
    case Actions.find(schema, params, options) do
      {:ok, schema_data} ->
        {:error,
         Error.call(
           :forbidden,
           "deleting the object for an existing record is not allowed",
           %{
             schema: schema,
             params: params,
             schema_data: schema_data
           },
           options
         )}

      {:error, %{code: :not_found}} ->
        :ok

      error ->
        error
    end
  end

  @doc """
  Fetches a database record by params and returns the record if the field `key` is not in
  a temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_upload(YourSchema, %{id: 1})
  """
  def find_permanent_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- Actions.find(schema, params, options),
         {:ok, schema_data} <- check_e_tag_non_nil(schema_data, options) do
      validate_permanent_object(schema_data, options)
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_upload(YourSchema, %{id: 1})
  """
  def find_completed_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- find_temporary_upload(schema, params, options) do
      check_e_tag_non_nil(schema_data, options)
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_upload(YourSchema, %{id: 1})
  """
  def find_temporary_upload(schema, params, options \\ []) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      validate_temporary_object(schema_data, options)
    end
  end

  @doc """
  ...
  """
  def delete_upload(bucket, schema, %_{} = schema_data, options) do
    operation = fn ->
      with {:ok, schema_data} <- validate_permanent_object(schema_data, options),
           {:ok, schema_data} <- Actions.delete(schema_data, options) do
        if Keyword.get(options, :scheduler_enabled?, true) do
          with {:ok, job} <-
                 Schedulers.queue_delete_object_if_upload_not_found(
                   bucket,
                   schema,
                   schema_data.key,
                   options[:schedule][:delete_object_if_upload_not_found] || @one_hour_seconds,
                   options
                 ) do
            {:ok,
             %{
               schema_data: schema_data,
               jobs: %{delete_object_if_upload_not_found: job}
             }}
          end
        else
          {:ok, %{schema_data: schema_data}}
        end
      end
    end

    Actions.transaction(operation, options)
  end

  def delete_upload(bucket, schema, params, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      delete_upload(bucket, schema, schema_data, options)
    end
  end

  def delete_upload(bucket, schema, params_or_schema_data) do
    delete_upload(bucket, schema, params_or_schema_data, [])
  end

  @doc """
  Fetches a temporary upload database record by params, then retrieves the metadata from
  the object and updates the field `:e_tag` on the database record to the value of the
  field `:e_tag` on the `metadata`.

  Returns an error if the database record field `:upload_id` is not `nil`. For multipart uploads
  use the function `&Uppy.Core.abort_multipart_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %YourSchema{id: 1})
      iex> Uppy.Core.complete_upload("bucket", YourSchema, %{id: 1})
  """
  def complete_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        %_{} = schema_data,
        update_params,
        options
      ) do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_non_multipart_upload(schema_data, options),
         {:ok, metadata} <-
           Storages.head_object(bucket, schema_data.key, options) do
      update_params = Map.put(update_params, :e_tag, metadata.e_tag)

      operation = fn ->
        with {:ok, schema_data} <- Actions.update(schema, schema_data, update_params, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_run_pipeline(
                     pipeline_module,
                     bucket,
                     resource_name,
                     schema,
                     schema_data.id,
                     options[:schedule][:run_pipeline],
                     options
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 schema_data: schema_data,
                 jobs: %{run_pipeline: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               schema_data: schema_data
             }}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def complete_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        find_params,
        update_params,
        options
      ) do
    with {:ok, schema_data} <- Actions.find(schema, find_params, options) do
      complete_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        schema_data,
        update_params,
        options
      )
    end
  end

  def complete_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        find_params_or_schema_data,
        update_params
      ) do
    complete_upload(
      bucket,
      resource_name,
      pipeline_module,
      schema,
      find_params_or_schema_data,
      update_params,
      []
    )
  end

  def complete_upload(
        bucket,
        resource_name,
        pipeline_module,
        schema,
        find_params_or_schema_data
      ) do
    complete_upload(
      bucket,
      resource_name,
      pipeline_module,
      schema,
      find_params_or_schema_data,
      %{}
    )
  end

  @doc """
  Fetches a temporary upload database record by params and deletes the record.

  Returns an error if the database record has the field `:upload_id` set. Multipart uploads
  should be aborted using the `&Uppy.Core.abort_multipart_upload/5` function.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_upload(YourSchema, %{id: 1})
  """
  def abort_upload(bucket, schema, %_{} = schema_data, options) do
    with {:ok, schema_data} <- validate_temporary_object(schema_data, options),
         {:ok, schema_data} <- check_if_non_multipart_upload(schema_data, options),
         {:ok, schema_data} <- check_e_tag_is_nil(schema_data, options) do
      operation = fn ->
        with {:ok, schema_data} <- Actions.delete(schema_data, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_delete_object_if_upload_not_found(
                     bucket,
                     schema,
                     schema_data.key,
                     options[:schedule][:delete_object_if_upload_not_found] || @one_hour_seconds,
                     options
                   ) do
              {:ok,
               %{
                 schema_data: schema_data,
                 jobs: %{delete_object_if_upload_not_found: job}
               }}
            end
          else
            {:ok, %{schema_data: schema_data}}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def abort_upload(bucket, schema, params, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      abort_upload(bucket, schema, schema_data, options)
    end
  end

  def abort_upload(bucket, schema, params_or_schema_data) do
    abort_upload(bucket, schema, params_or_schema_data, [])
  end

  @doc """
  Creates a presigned url and a database record.

  The process of starting an upload is as follows:

      1. A unique identifier is generated and put into the `params` key `:unique_identifier`
        if the key is not set.

      2. A `basename` string is created using the `unique_identifier` and `filename`.

      3. A `key` is generated for a temporary object by the `temporary_object_key_adapter` given
        the `partition_id` and `basename`.

      4. The `key` generated in the previous step is signed by the `storage_adapter`.

      5. A database record is created for the temporary upload and the keys `:unique_identifier`,
        `filename`, and `:key` are set in the `params` map (These values are created in the
        previous steps).

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storages` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_upload(bucket, partition_id, schema, params, options) when is_integer(partition_id) do
    start_upload(bucket, Integer.to_string(partition_id), schema, params, options)
  end

  def start_upload(bucket, partition_id, schema, params, options) when is_binary(partition_id) do
    filename = params.filename
    unique_identifier = maybe_generate_unique_identifier(params[:unique_identifier], options)
    basename = basename(unique_identifier, filename)

    key = TemporaryObjectKeys.prefix(partition_id, basename, options)

    params =
      Map.merge(params, %{
        unique_identifier: unique_identifier,
        filename: filename,
        key: key
      })

    with {:ok, presigned_upload} <- Storages.presigned_upload(bucket, key, options) do
      operation = fn ->
        with {:ok, schema_data} <- Actions.create(schema, params, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
                   Schedulers.queue_abort_upload(
                     bucket,
                     schema,
                     schema_data.id,
                     options[:schedule][:abort_upload] || @one_hour_seconds,
                     options
                   ) do
              {:ok,
               %{
                 unique_identifier: unique_identifier,
                 basename: basename,
                 key: key,
                 presigned_upload: presigned_upload,
                 schema_data: schema_data,
                 jobs: %{abort_upload: job}
               }}
            end
          else
            {:ok,
             %{
               unique_identifier: unique_identifier,
               basename: basename,
               key: key,
               presigned_upload: presigned_upload,
               schema_data: schema_data
             }}
          end
        end
      end

      Actions.transaction(operation, options)
    end
  end

  def start_upload(bucket, partition_id, schema, params) do
    start_upload(bucket, partition_id, schema, params, [])
  end

  defp maybe_generate_unique_identifier(nil, options), do: generate_unique_identifier(options)
  defp maybe_generate_unique_identifier(unique_identifier, _options), do: unique_identifier

  defp validate_permanent_object(schema_data, options) do
    if Keyword.get(options, :validate?, true) do
      Utils.Logger.debug(
        @logger_prefix,
        "validating permanent object key #{inspect(schema_data.key)}"
      )

      with {:ok, path} <- PermanentObjectKeys.validate(schema_data.key, options) do
        Utils.Logger.debug(
          @logger_prefix,
          "validated permanent object key #{inspect(schema_data.key)}, got: #{inspect(path)}"
        )

        {:ok, schema_data}
      end
    else
      Utils.Logger.debug(
        @logger_prefix,
        "skipping validation for permanent object key #{inspect(schema_data.key)}"
      )

      {:ok, schema_data}
    end
  end

  defp validate_temporary_object(schema_data, options) do
    if Keyword.get(options, :validate?, true) do
      Utils.Logger.debug(
        @logger_prefix,
        "validating temporary object key #{inspect(schema_data.key)}"
      )

      with {:ok, path} <- TemporaryObjectKeys.validate(schema_data.key, options) do
        Utils.Logger.debug(
          @logger_prefix,
          "validated temporary object key #{inspect(schema_data.key)}, got: #{inspect(path)}"
        )

        {:ok, schema_data}
      end
    else
      Utils.Logger.debug(
        @logger_prefix,
        "skipping validation for temporary object key #{inspect(schema_data.key)}"
      )

      {:ok, schema_data}
    end
  end

  defp check_e_tag_is_nil(schema_data, options) do
    if is_nil(schema_data.e_tag) do
      {:ok, schema_data}
    else
      {:error,
       Error.call(
         :forbidden,
         "Expected field `:e_tag` to be nil",
         %{schema_data: schema_data},
         options
       )}
    end
  end

  defp check_e_tag_non_nil(schema_data, options) do
    if is_nil(schema_data.e_tag) === false do
      {:ok, schema_data}
    else
      {:error,
       Error.call(
         :forbidden,
         "Expected field `:e_tag` to be non-nil",
         %{
           schema_data: schema_data
         },
         options
       )}
    end
  end

  defp check_if_multipart_upload(schema_data, options) do
    if has_upload_id?(schema_data) do
      {:ok, schema_data}
    else
      {:error,
       Error.call(
         :forbidden,
         "Expected `:upload_id` to be non-nil",
         %{schema_data: schema_data},
         options
       )}
    end
  end

  defp check_if_non_multipart_upload(schema_data, options) do
    if has_upload_id?(schema_data) === false do
      {:ok, schema_data}
    else
      {:error,
       Error.call(
         :forbidden,
         "Expected `:upload_id` to be nil",
         %{
           schema_data: schema_data
         },
         options
       )}
    end
  end

  defp has_upload_id?(%{upload_id: nil}), do: false
  defp has_upload_id?(%{upload_id: _}), do: true
end
