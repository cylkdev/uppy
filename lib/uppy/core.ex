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
    Config,
    Error,
    TemporaryObjectKeys,
    Pipeline,
    Pipelines,
    Schedulers,
    Storage,
    Utils
  }

  @default_actions_adapter Uppy.Adapters.Action
  @default_scheduler_adapter Uppy.Adapters.Scheduler.Oban
  @default_storage_adapter Uppy.Adapters.Storage
  @default_temporary_object_key_adapter Uppy.Adapters.TemporaryObjectKey

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

  def delete_upload(bucket, schema, params, options) do
    actions_adapter = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)

    operation =
      fn ->
        with {:ok, schema_data} <- Actions.find(actions_adapter, schema, params, options),
          {:ok, schema_data} <- Actions.delete(actions_adapter, schema_data, options) do
          if Keyword.get(options, :scheduler_enabled?, true) do
            with {:ok, job} <-
              Schedulers.queue_garbage_collect_object(
                scheduler_adapter,
                bucket,
                schema,
                schema_data.key,
                options[:schedule][:garbage_collect_object] || @one_hour_seconds,
                options
              ) do
              {:ok, %{
                schema_data: schema_data,
                jobs: %{garbage_collect_object: job}
              }}
            end
          else
            {:ok, %{schema_data: schema_data}}
          end
        end
      end

    Actions.transaction(actions_adapter, operation, options)
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata retrieved
  from the function `&Storage.complete_multipart_upload/6`.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

  ### Examples

      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1, prefix: "prefix")
      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1)
      iex> Uppy.Core.presigned_part("bucket", "unique_id", YourSchema, %{id: 1}, 1)
  """
  def presigned_part(bucket, schema, params, part_number, options) do
    storage_adapter = storage_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, params, options),
         {:ok, schema_data} <- ensure_multipart_upload(schema_data),
         {:ok, presigned_part} <-
          Storage.presigned_part_upload(
            storage_adapter,
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

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata retrieved
  from the function `&Storage.complete_multipart_upload/6`.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

  ### Examples

      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, nil, prefix: "prefix")
      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def find_parts(bucket, schema, params, maybe_next_part_number_marker, options) do
    storage_adapter = storage_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, params, options),
         {:ok, schema_data} <- ensure_multipart_upload(schema_data),
         {:ok, parts} <-
           Storage.list_parts(
             storage_adapter,
             bucket,
             schema_data.key,
             schema_data.upload_id,
             maybe_next_part_number_marker,
             options
           ) do
      {:ok,
       %{
         parts: parts,
         schema_data: schema_data
       }}
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_multipart_upload(YourSchema, %{id: 1})
  """
  def find_permanent_multipart_upload(schema, params, options) do
    with {:ok, schema_data} <- find_permanent_upload(schema, params, options) do
      ensure_multipart_upload(schema_data)
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_multipart_upload(YourSchema, %{id: 1})
  """
  def find_completed_multipart_upload(schema, params, options) do
    with {:ok, schema_data} <- find_completed_upload(schema, params, options) do
      ensure_multipart_upload(schema_data)
    end
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata returned
  from the storage `&Storage.complete_multipart_upload/6` function.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

  ### Examples

      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}], prefix: "prefix")
      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}])
      iex> Uppy.Core.complete_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1}, [{1, "e_tag"}])
  """
  def complete_multipart_upload(bucket, resource_name, schema, find_params, update_params, parts, pipeline_module, options) do
    actions_adapter = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)
    storage_adapter = storage_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, find_params, options),
      {:ok, schema_data} <- ensure_multipart_upload(schema_data),
      {:ok, metadata} <- complete_multipart_upload_or_head_object(
        storage_adapter,
        bucket,
        schema_data,
        parts,
        options
      ) do

      update_params = Map.put(update_params, :e_tag, metadata.e_tag)

      operation =
        fn ->
          with {:ok, schema_data} <-
            Actions.update(actions_adapter, schema, schema_data, update_params, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_run_pipeline(
                  scheduler_adapter,
                  bucket,
                  resource_name,
                  schema,
                  schema_data.id,
                  pipeline_module,
                  options[:schedule][:run_pipeline],
                  options
                ) do
                {:ok, %{
                  metadata: metadata,
                  schema_data: schema_data,
                  jobs: %{run_pipeline: job}
                }}
              end
            else
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data
              }}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  defp complete_multipart_upload_or_head_object(
    storage_adapter,
    bucket,
    schema_data,
    parts,
    options
  ) do
    with {:error, %{code: :not_found}} <-
      Storage.complete_multipart_upload(
        storage_adapter,
        bucket,
        schema_data.key,
        schema_data.upload_id,
        parts,
        options
      ) do
      Storage.head_object(storage_adapter, bucket, schema_data.key, options)
    end
  end

  @doc """
  Fetches a temporary upload database record by params, aborts the multipart upload and deletes the record.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def abort_multipart_upload(bucket, schema, params, options \\ []) do
    actions_adapter = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)
    storage_adapter = storage_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, params, options),
        {:ok, schema_data} <- ensure_multipart_upload(schema_data),
        {:ok, maybe_metadata} <-
          handle_abort_multipart_upload(
            storage_adapter,
            bucket,
            schema_data.key,
            schema_data.upload_id,
            options
          ) do
      operation =
        fn ->
          with {:ok, schema_data} <- Actions.delete(actions_adapter, schema_data, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_garbage_collect_object(
                  scheduler_adapter,
                  bucket,
                  schema,
                  schema_data.key,
                  options[:schedule][:garbage_collect_object] || @one_hour_seconds,
                  options
                ) do
                {:ok, %{
                  metadata: maybe_metadata,
                  schema_data: schema_data,
                  jobs: %{garbage_collect_object: job}
                }}
              end
            else
              {:ok, %{
                metadata: maybe_metadata,
                schema_data: schema_data
              }}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  defp handle_abort_multipart_upload(storage_adapter, bucket, key, upload_id, options) do
    case Storage.abort_multipart_upload(storage_adapter, bucket, key, upload_id, options) do
      {:ok, metadata} -> {:ok, %{metadata: metadata}}
      {:error, %{code: :not_found}} -> {:ok, :not_found}
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_multipart_upload(YourSchema, %{id: 1})
  """
  def find_temporary_multipart_upload(schema, params, options) do
    with {:ok, schema_data} <- find_temporary_upload(schema, params, options) do
      ensure_multipart_upload(schema_data)
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
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_multipart_upload(bucket, partition_id, schema, params, options) when is_integer(partition_id) do
    start_multipart_upload(bucket, Integer.to_string(partition_id), schema, params, options)
  end

  def start_multipart_upload(bucket, partition_id, schema, params, options) when is_binary(partition_id) do
    actions_adapter   = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)
    storage_adapter   = storage_adapter!(options)
    temporary_object_key_adapter = temporary_object_key_adapter!(options)

    filename = params.filename
    unique_identifier = maybe_generate_unique_identifier(params[:unique_identifier], options)

    basename = basename(unique_identifier, filename)
    key = TemporaryObjectKeys.prefix(temporary_object_key_adapter, partition_id, basename)

    params = Map.merge(params, %{
      unique_identifier: unique_identifier,
      filename: filename,
      key: key
    })

    with {:ok, multipart_upload} <- Storage.initiate_multipart_upload(storage_adapter, bucket, key, options) do
      operation =
        fn ->
          with {:ok, schema_data} <- Actions.create(actions_adapter, schema, params, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_abort_multipart_upload(
                  scheduler_adapter,
                  bucket,
                  schema,
                  schema_data.id,
                  options[:schedule][:abort_multipart_upload] || @one_hour_seconds,
                  options
                ) do
                {:ok, %{
                  unique_identifier: unique_identifier,
                  basename: basename,
                  key: key,
                  multipart_upload: multipart_upload,
                  schema_data: schema_data,
                  jobs: %{abort_multipart_upload: job}
                }}
              end
            else
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                multipart_upload: multipart_upload,
                schema_data: schema_data
              }}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  defp maybe_generate_unique_identifier(nil, options), do: generate_unique_identifier(options)
  defp maybe_generate_unique_identifier(unique_identifier, _options), do: unique_identifier

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
  def run_pipeline(pipeline_module_or_pipeline, bucket, resource_name, schema, params_or_schema_data, options \\ [])

  def run_pipeline(pipeline_module, bucket, resource_name, schema, params_or_schema_data, options) when is_atom(pipeline_module) do
    pipeline_module
    |> Pipelines.pipeline()
    |> run_pipeline(bucket, resource_name, schema, params_or_schema_data, options)
  end

  def run_pipeline(pipeline, bucket, resource_name, schema, %_{} = schema_data, options) do
    context = Keyword.get(options, :context, %{})

    input = %{
      bucket: bucket,
      resource_name: resource_name,
      schema: schema,
      schema_data: schema_data,
      context: context,
      options: options
    }

    pipeline = ensure_validate_permanent_object_key_last(pipeline)

    with {:ok, output, executed_phases} <- Pipeline.run(input, pipeline) do
      {:ok, %{input: input, output: output, phases: executed_phases}}
    end
  end

  def run_pipeline(pipeline, bucket, resource_name, schema, params, options) do
    actions_adapter = actions_adapter!(options)

    with  {:ok, schema_data} <- Actions.find(actions_adapter, schema, params, options) do
      run_pipeline(pipeline, bucket, resource_name, schema, schema_data, options)
    end
  end

  defp ensure_validate_permanent_object_key_last(pipeline) do
    pipeline
    |> Enum.reject(&(&1 === Uppy.Pipeline.Phases.ValidatePermanentObjectKey))
    |> Kernel.++([Uppy.Pipeline.Phases.ValidatePermanentObjectKey])
  end

  @doc """
  Fetches a temporary upload database record by params, then retrieves the metadata from
  the object and updates the field `:e_tag` on the database record to the value of the
  field `:e_tag` on the `metadata`.

  Returns an error if the database record field `:upload_id` is not `nil`. For multipart uploads
  use the function `&Uppy.Core.abort_multipart_upload/5`.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.complete_upload("bucket", {YourSchema, "source"}, %YourSchema{id: 1})
      iex> Uppy.Core.complete_upload("bucket", YourSchema, %{id: 1})
  """
  def complete_upload(bucket, resource_name, schema, find_params, update_params, pipeline_module, options) do
    actions_adapter = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)
    storage_adapter = storage_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, find_params, options),
        {:ok, schema_data} <- ensure_non_multipart_upload(schema_data),
        {:ok, metadata} <- Storage.head_object(storage_adapter, bucket, schema_data.key, options) do

      update_params = Map.merge(update_params, %{e_tag: metadata.e_tag})

      operation =
        fn ->
          with {:ok, schema_data} <-
            Actions.update(actions_adapter, schema, schema_data, update_params, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_run_pipeline(
                  scheduler_adapter,
                  bucket,
                  resource_name,
                  schema,
                  schema_data.id,
                  pipeline_module,
                  options[:schedule][:run_pipeline],
                  options
                ) do
                {:ok, %{
                  metadata: metadata,
                  schema_data: schema_data,
                  jobs: %{run_pipeline: job}
                }}
              end
            else
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data
              }}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  @doc """
  Deletes the object specified by `key` from storage if the database record does not exist.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

  ### Examples

      iex> Uppy.Core.garbage_collect_object("bucket", {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.garbage_collect_object("bucket", {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.garbage_collect_object("bucket", YourSchema, %{id: 1})
  """
  def garbage_collect_object(bucket, schema, key, options \\ []) do
    actions_adapter = actions_adapter!(options)
    storage_adapter = storage_adapter!(options)

    with :ok <- ensure_not_found(actions_adapter, schema, %{key: key}, options),
      {:ok, _} <- Storage.head_object(storage_adapter, bucket, key, options),
      {:ok, _} <- Storage.delete_object(storage_adapter, bucket, key, options) do
      :ok
    else
      {:error, %{code: :not_found}} -> :ok
      error -> error
    end
  end

  defp ensure_not_found(actions_adapter, schema, params, options) do
    case Actions.find(actions_adapter, schema, params, options) do
      {:ok, schema_data} ->
        details = %{
          schema: schema,
          params: params,
          schema_data: schema_data
        }

        {:error, Error.call(:forbidden, "record found", details)}

      {:error, %{code: :not_found}} ->
        :ok

      error ->
        error
    end
  end

  @doc """
  Fetches a temporary upload database record by params and deletes the record.

  Returns an error if the database record has the field `:upload_id` set. Multipart uploads
  should be aborted using the `&Uppy.Core.abort_multipart_upload/5` function.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_upload(YourSchema, %{id: 1})
  """
  def abort_upload(bucket, schema, params, options \\ []) do
    actions_adapter = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)

    with {:ok, schema_data} <- find_temporary_upload(schema, params, options),
        {:ok, schema_data} <- ensure_non_multipart_upload(schema_data),
        {:ok, schema_data} <- ensure_upload_not_complete(schema_data) do
      operation =
        fn ->
          with {:ok, schema_data} <- Actions.delete(actions_adapter, schema_data, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_garbage_collect_object(
                  scheduler_adapter,
                  bucket,
                  schema,
                  schema_data.key,
                  options[:schedule][:garbage_collect_object] || @one_hour_seconds,
                  options
                ) do
                {:ok, %{
                  schema_data: schema_data,
                  jobs: %{garbage_collect_object: job}
                }}
              end
            else
              {:ok, %{schema_data: schema_data}}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  defp ensure_upload_not_complete(schema_data) do
    if is_nil(schema_data.e_tag) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden, "cannot abort completed upload", %{schema_data: schema_data})}
    end
  end

  @doc """
  Fetches a database record by params and returns the record if the field `key` is not in
  a temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_upload(YourSchema, %{id: 1})
  """
  def find_permanent_upload(schema, params, options) do
    actions_adapter = actions_adapter!(options)
    temporary_object_key_adapter = temporary_object_key_adapter!(options)

    with {:ok, schema_data} <- Actions.find(actions_adapter, schema, params, options) do
      case TemporaryObjectKeys.validate(temporary_object_key_adapter, schema_data.key) do
        {:ok, _path} ->
          if is_nil(schema_data.e_tag) === false do
            {:ok, schema_data}
          else
            {:error, Error.call(:forbidden, "permanent upload does not contain an e-tag", %{
              schema: schema,
              schema_data: schema_data,
              params: params
            })}
          end

        {:error, error} ->
          {:error, Error.call(:forbidden, "not a permanent upload", %{
            schema: schema,
            schema_data: schema_data,
            params: params,
            error: error
          })}
      end
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_upload(YourSchema, %{id: 1})
  """
  def find_completed_upload(schema, params, options) do
    with {:ok, schema_data} <- find_temporary_upload(schema, params, options) do
      if is_nil(schema_data.e_tag) === false do
        {:ok, schema_data}
      else
        details = %{
          schema: schema,
          schema_data: schema_data,
          params: params
        }

        {:error, Error.call(:forbidden, "upload incomplete", details)}
      end
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:actions_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_upload(YourSchema, %{id: 1})
  """
  def find_temporary_upload(schema, params, options) do
    actions_adapter = actions_adapter!(options)
    temporary_object_key_adapter = temporary_object_key_adapter!(options)

    with {:ok, schema_data} <- Actions.find(actions_adapter, schema, params, options) do
      case TemporaryObjectKeys.validate(temporary_object_key_adapter, schema_data.key) do
        {:ok, _path} -> {:ok, schema_data}
        {:error, error} ->
          {:error, Error.call(:forbidden, "not a temporary upload", %{
            schema: schema,
            schema_data: schema_data,
            params: params,
            error: error
          })}
      end
    end
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
        module documentation for more information. Defaults to #{inspect(@default_actions_adapter)}.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Adapter.Storage` module documentation for more information. Defaults to
        #{inspect(@default_storage_adapter)}.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information. Defaults to #{inspect(@default_temporary_object_key_adapter)}.

  ### Examples

      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_upload(bucket, partition_id, schema, params, options) when is_integer(partition_id) do
    start_upload(bucket, Integer.to_string(partition_id), schema, params, options)
  end

  def start_upload(bucket, partition_id, schema, params, options) when is_binary(partition_id) do
    actions_adapter   = actions_adapter!(options)
    scheduler_adapter = scheduler_adapter!(options)
    storage_adapter   = storage_adapter!(options)
    temporary_object_key_adapter = temporary_object_key_adapter!(options)

    filename = params.filename
    unique_identifier = maybe_generate_unique_identifier(params[:unique_identifier], options)
    basename = basename(unique_identifier, filename)
    key = TemporaryObjectKeys.prefix(temporary_object_key_adapter, partition_id, basename)

    params = Map.merge(params, %{
      unique_identifier: unique_identifier,
      filename: filename,
      key: key
    })

    with {:ok, presigned_upload} <- Storage.presigned_upload(storage_adapter, bucket, key, options) do
      operation =
        fn ->
          with {:ok, schema_data} <- Actions.create(actions_adapter, schema, params, options) do
            if Keyword.get(options, :scheduler_enabled?, true) do
              with {:ok, job} <-
                Schedulers.queue_abort_upload(
                  scheduler_adapter,
                  bucket,
                  schema,
                  schema_data.id,
                  options[:schedule][:abort_upload] || @one_hour_seconds,
                  options
                ) do
                {:ok, %{
                  unique_identifier: unique_identifier,
                  basename: basename,
                  key: key,
                  presigned_upload: presigned_upload,
                  schema_data: schema_data,
                  jobs: %{abort_upload: job}
                }}
              end
            else
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                presigned_upload: presigned_upload,
                schema_data: schema_data
              }}
            end
          end
        end

      Actions.transaction(actions_adapter, operation, options)
    end
  end

  defp ensure_multipart_upload(schema_data) do
    if has_upload_id?(schema_data) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden, "Expected a multipart upload", %{schema_data: schema_data})}
    end
  end

  defp ensure_non_multipart_upload(schema_data) do
    if has_upload_id?(schema_data) do
      {:error, Error.call(:forbidden, "Expected a non multipart upload", %{schema_data: schema_data})}
    else
      {:ok, schema_data}
    end
  end

  defp has_upload_id?(%{upload_id: nil}), do: false
  defp has_upload_id?(%{upload_id: upload_id}) when is_binary(upload_id), do: true

  defp actions_adapter!(options) do
    Keyword.get(options, :actions_adapter, Config.actions_adapter()) || @default_actions_adapter
  end

  defp scheduler_adapter!(options) do
    Keyword.get(options, :scheduler_adapter, Config.scheduler_adapter()) || @default_scheduler_adapter
  end

  defp storage_adapter!(options) do
    Keyword.get(options, :storage_adapter, Config.storage_adapter()) || @default_storage_adapter
  end

  defp temporary_object_key_adapter!(options) do
    Keyword.get(options, :temporary_object_key_adapter, Config.temporary_object_key_adapter()) || @default_temporary_object_key_adapter
  end
end
