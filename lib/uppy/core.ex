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
    DBAction,
    Error,
    PathBuilder,
    Pipeline,
    Resolution,
    Scheduler,
    Storage,
    Utils
  }

  @unique_identifier_byte_size 32
  @one_hour_seconds 3_600
  @upload_http_method :post
  @scheduler_disabled :scheduler_disabled

  @doc """
  Returns a string in the format of `<unique_identifier>-<filename>`.

  ### Examples

      iex> Uppy.Core.basename("unique_identifier", "filename")
      "unique_identifier-filename"
  """
  def basename(unique_identifier, filename) do
    "#{unique_identifier}-#{filename}"
  end

  def basename(%{unique_identifier: unique_identifier, filename: filename}) do
    basename(unique_identifier, filename)
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_multipart_upload(YourSchema, %{id: 1})
  """
  def find_permanent_multipart_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- find_permanent_upload(query, params, opts) do
      check_if_multipart_upload(schema_data)
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_multipart_upload(YourSchema, %{id: 1})
  """
  def find_completed_multipart_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- find_completed_upload(query, params, opts) do
      check_if_multipart_upload(schema_data)
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_multipart_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_multipart_upload(YourSchema, %{id: 1})
  """
  def find_temporary_multipart_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- find_temporary_upload(query, params, opts) do
      check_if_multipart_upload(schema_data)
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
        `Uppy.Storage` module documentation for more information.

  ### Examples

      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, nil, prefix: "prefix")
      iex> Uppy.Core.find_parts("bucket", 1, {YourSchema, "source"}, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1}, "next_part_number_marker")
      iex> Uppy.Core.find_parts("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def find_parts(
    bucket,
    query,
    find_params_or_schema_data,
    next_part_number_marker \\ nil,
    opts \\ []
  )

  def find_parts(
    bucket,
    _query,
    %_{} = schema_data,
    next_part_number_marker,
    opts
  ) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
      {:ok, schema_data} <- check_if_multipart_upload(schema_data),
      {:ok, parts} <-
        Storage.list_parts(
          bucket,
          schema_data.key,
          schema_data.upload_id,
          next_part_number_marker,
          opts
        ) do
      {:ok, %{
        parts: parts,
        schema_data: schema_data
      }}
    end
  end

  def find_parts(bucket, query, find_params, next_part_number_marker, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_data, next_part_number_marker, opts)
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
        `Uppy.Storage` module documentation for more information.

  ### Examples

      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1, prefix: "prefix")
      iex> Uppy.Core.presigned_part("bucket", 1, {YourSchema, "source"}, %{id: 1}, 1)
      iex> Uppy.Core.presigned_part("bucket", "unique_id", YourSchema, %{id: 1}, 1)
  """
  def presigned_part(bucket, query, params_or_schema_data, part_number, opts \\ [])

  def presigned_part(bucket, _query, %_{} = schema_data, part_number, opts) do
    http_method = upload_http_method(opts)

    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
         {:ok, schema_data} <- check_if_multipart_upload(schema_data),
         {:ok, presigned_part} <-
          Storage.presigned_part_upload(
            bucket,
            http_method,
            schema_data.key,
            schema_data.upload_id,
            part_number,
            opts
          ) do
      {:ok, %{
        presigned_part: presigned_part,
        schema_data: schema_data
      }}
    end
  end

  def presigned_part(bucket, query, params, part_number, opts) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      presigned_part(bucket, query, schema_data, part_number, opts)
    end
  end

  @doc """
  Fetches a temporary upload database record by params, completes the multipart upload and updates the
  field `:e_tag` on the database record to the value of the field `:e_tag` on the metadata returned
  from the storage `&Storage.complete_multipart_upload/6` function.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

  ### Examples

      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}], prefix: "prefix")
      iex> Uppy.Core.complete_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, [{1, "e_tag"}])
      iex> Uppy.Core.complete_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1}, [{1, "e_tag"}])
  """
  def complete_multipart_upload(
    bucket,
    resource,
    pipeline,
    query,
    schema_data,
    parts,
    update_params \\ %{},
    opts \\ []
  )

  def complete_multipart_upload(
    bucket,
    resource,
    pipeline,
    query,
    %_{} = schema_data,
    parts,
    update_params,
    opts
  ) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
      {:ok, schema_data} <- check_if_multipart_upload(schema_data),
      {:ok, metadata} <-
        complete_and_head_multipart_upload(
          bucket,
          schema_data,
          parts,
          opts
        ) do
      update_params = Map.put(update_params, :e_tag, metadata.e_tag)

      operation = fn ->
        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          case queue_process_upload(
            pipeline,
            bucket,
            resource,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data
              }}

            {:ok, process_upload_job} ->
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data,
                jobs: %{
                  process_upload: process_upload_job
                }
              }}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  def complete_multipart_upload(
    bucket,
    resource,
    pipeline,
    query,
    find_params,
    parts,
    update_params,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        resource,
        pipeline,
        query,
        schema_data,
        parts,
        update_params,
        opts
      )
    end
  end

  defp complete_and_head_multipart_upload(
    bucket,
    schema_data,
    parts,
    opts
  ) do
    case Storage.complete_multipart_upload(
      bucket,
      schema_data.key,
      schema_data.upload_id,
      parts,
      opts
    ) do
      {:ok, _} -> Storage.head_object(bucket, schema_data.key, opts)
      {:error, %{code: :not_found}} -> Storage.head_object(bucket, schema_data.key, opts)
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetches a temporary upload database record by params, aborts the multipart upload and deletes the record.

  Returns an error if the database record field `:upload_id` is nil. For non multipart uploads use the
  function `&Uppy.Core.abort_upload/5`.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def abort_multipart_upload(bucket, query, find_params_or_schema_data, opts \\ [])

  def abort_multipart_upload(bucket, query, %_{} = schema_data, opts) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
      {:ok, schema_data} <- check_if_multipart_upload(schema_data),
      {:ok, metadata} <-
        handle_abort_multipart_upload(
          bucket,
          schema_data.key,
          schema_data.upload_id,
          opts
        ) do

      payload = if is_nil(metadata), do: %{}, else: %{metadata: metadata}

      operation = fn ->
        with {:ok, schema_data} <- DBAction.delete(schema_data, opts) do
          case queue_garbage_collect_object(
            bucket,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, Map.merge(payload, %{
                schema_data: schema_data
              })}

            {:ok, garbage_collect_job} ->
              {:ok, Map.merge(payload, %{
                schema_data: schema_data,
                jobs: %{
                  garbage_collect_object: garbage_collect_job
                }
              })}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  def abort_multipart_upload(bucket, query, params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      abort_multipart_upload(bucket, query, schema_data, opts)
    end
  end

  defp handle_abort_multipart_upload(bucket, key, upload_id, opts) do
    case Storage.abort_multipart_upload(bucket, key, upload_id, opts) do
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

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_multipart_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_multipart_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_multipart_upload(bucket, partition_id, query, params, opts \\ []) do
    filename = params.filename
    unique_identifier = generate_unique_identifier(params[:unique_identifier], opts)
    basename = basename(unique_identifier, filename)

    key = PathBuilder.temporary_path(%{id: partition_id, basename: basename}, opts)

    with {:ok, multipart_upload} <- Storage.initiate_multipart_upload(bucket, key, opts) do
      create_params =
        Map.merge(params, %{
          upload_id: multipart_upload.upload_id,
          unique_identifier: unique_identifier,
          filename: filename,
          key: key
        })

      operation = fn ->
        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          case queue_abort_multipart_upload(
            bucket,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                multipart_upload: multipart_upload,
                schema_data: schema_data
              }}

            {:ok, abort_multipart_upload_job} ->
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                multipart_upload: multipart_upload,
                schema_data: schema_data,
                jobs: %{
                  abort_multipart_upload: abort_multipart_upload_job
                }
              }}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  @doc """
  Executes a list of phases on a given database record.

  The first phase in the pipeline is given the `input` argument specified to this function. The `input` is
  expected to be a `map` that contains the specified fields specified below.

  The required input fields are:

      * `bucket` - The name of the bucket.

      * `resource` - The name of the resource being uploaded to the bucket as a string, for eg. "avatars".

      * `schema` - The `Ecto.Schema` module.

      * `schema_data` - A `schema` named struct. This is the database record for the upload.

      * `opts` - A keyword list of runtime opts.

  See the `Uppy.Pipeline` module documentation for more information on the pipeline.
  """
  def process_upload(
    bucket,
    pipeline,
    resource,
    query,
    %_{} = schema_data,
    opts
  ) do
    process_upload(
      pipeline,
      %Resolution{
        bucket: bucket,
        resource: resource,
        query: query,
        value: schema_data
      },
      opts
    )
  end

  def process_upload(
    bucket,
    pipeline,
    resource,
    query,
    params,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      process_upload(
        bucket,
        pipeline,
        resource,
        query,
        schema_data,
        opts
      )
    end
  end

  def process_upload(
    bucket,
    pipeline,
    resource,
    query,
    params_or_schema_data
  ) do
    process_upload(
      bucket,
      pipeline,
      resource,
      query,
      params_or_schema_data,
      []
    )
  end

  def process_upload(pipeline, resolution, opts) when is_atom(pipeline) do
    pipeline
    |> Pipeline.phases(opts)
    |> process_upload(resolution, opts)
  end

  def process_upload(phases, resolution, _opts) do
    with {:ok, resolution, done} <- Pipeline.run(resolution, phases) do
      {:ok, Resolution.resolve(resolution), done}
    end
  end

  def process_upload(pipeline, resolution) do
    process_upload(pipeline, resolution, [])
  end

  @doc """
  Deletes the object specified by `key` from storage if the database record does not exist.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

  ### Examples

      iex> Uppy.Core.garbage_collect_object("bucket", {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.garbage_collect_object("bucket", {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.garbage_collect_object("bucket", YourSchema, %{id: 1})
  """
  def garbage_collect_object(bucket, query, params_or_key, opts \\ [])

  def garbage_collect_object(bucket, query, key, opts) when is_binary(key) do
    garbage_collect_object(bucket, query, %{key: key}, opts)
  end

  def garbage_collect_object(bucket, query, params, opts) do
    key = params.key

    with :ok <- validate_garbage_collection(query, params, opts) do
      case Storage.head_object(bucket, key, opts) do
        {:ok, metadata} ->
          with {:ok, _} <- Storage.delete_object(bucket, key, opts) do
            {:ok, metadata}
          end

        {:error, %{code: :not_found}} -> {:ok, nil}

        error -> error
      end
    end
  end

  defp validate_garbage_collection(query, params, opts) do
    case DBAction.find(query, params, opts) do
      {:ok, schema_data} ->
        {:error, Error.call(:forbidden, "cannot garbage collect existing record", %{
          query: query,
          params: params,
          schema_data: schema_data
        })}

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

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_permanent_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_permanent_upload(YourSchema, %{id: 1})
  """
  def find_permanent_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts),
      :ok <- PathBuilder.validate_permanent_path(schema_data.key, opts) do
      check_e_tag_non_nil(schema_data)
    end
  end

  @doc """
  Fetches a temporary upload database record by params and returns the record if the field `e_tag` is not nil.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_completed_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_completed_upload(YourSchema, %{id: 1})
  """
  def find_completed_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- find_temporary_upload(query, params, opts) do
      check_e_tag_non_nil(schema_data)
    end
  end

  @doc """
  Fetches the database record by params and returns the record if the field `key` is
  in the temporary path.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.find_temporary_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.find_temporary_upload(YourSchema, %{id: 1})
  """
  def find_temporary_upload(query, params, opts \\ []) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts),
      :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts) do
      {:ok, schema_data}
    end
  end

  @doc """
  ...
  """
  def delete_upload(bucket, query, find_params_or_schema_data, opts \\ [])

  def delete_upload(bucket, query, %_{} = schema_data, opts) do
    operation = fn ->
      with :ok <- PathBuilder.validate_permanent_path(schema_data.key, opts),
        {:ok, schema_data} <- DBAction.delete(schema_data, opts) do
        case queue_garbage_collect_object(
          bucket,
          query,
          schema_data,
          opts
        ) do
          @scheduler_disabled ->
            {:ok, %{
              schema_data: schema_data
            }}

          {:ok, garbage_collect_job} ->
            {:ok, %{
              schema_data: schema_data,
              jobs: %{
                garbage_collect_object: garbage_collect_job
              }
            }}

          error -> error
        end
      end
    end

    DBAction.transaction(operation, opts)
  end

  def delete_upload(bucket, query, params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      delete_upload(bucket, query, schema_data, opts)
    end
  end

  @doc """
  Fetches a temporary upload database record by params, then retrieves the metadata from
  the object and updates the field `:e_tag` on the database record to the value of the
  field `:e_tag` on the `metadata`.

  Returns an error if the database record field `:upload_id` is not `nil`. For multipart uploads
  use the function `&Uppy.Core.abort_multipart_upload/5`.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

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
    resource,
    pipeline,
    query,
    find_params_or_schema_data,
    update_params \\ %{},
    opts \\ []
  )

  def complete_upload(
    bucket,
    resource,
    pipeline,
    query,
    %_{} = schema_data,
    update_params,
    opts
  ) when is_atom(pipeline) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
      {:ok, schema_data} <- check_if_non_multipart_upload(schema_data),
      {:ok, metadata} <- Storage.head_object(bucket, schema_data.key, opts) do
      update_params = Map.put(update_params, :e_tag, metadata.e_tag)

      operation = fn ->
        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          case queue_process_upload(
            pipeline,
            bucket,
            resource,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data
              }}

            {:ok, process_upload_job} ->
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data,
                jobs: %{
                  process_upload: process_upload_job
                }
              }}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  def complete_upload(
    bucket,
    resource,
    pipeline,
    query,
    find_params,
    update_params,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_upload(
        bucket,
        resource,
        pipeline,
        query,
        schema_data,
        update_params,
        opts
      )
    end
  end

  @doc """
  Fetches a temporary upload database record by params and deletes the record.

  Returns an error if the database record has the field `:upload_id` set. Multipart uploads
  should be aborted using the `&Uppy.Core.abort_multipart_upload/5` function.

  ### Options

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.abort_upload({YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.abort_upload(YourSchema, %{id: 1})
  """
  def abort_upload(bucket, query, find_params_or_schema_data, opts \\ [])

  def abort_upload(bucket, query, %_{} = schema_data, opts) do
    with :ok <- PathBuilder.validate_temporary_path(schema_data.key, opts),
         {:ok, schema_data} <- check_if_non_multipart_upload(schema_data),
         {:ok, schema_data} <- check_e_tag_is_nil(schema_data) do
      operation = fn ->
        with {:ok, schema_data} <- DBAction.delete(schema_data, opts) do
          case queue_garbage_collect_object(
            bucket,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, %{
                schema_data: schema_data,
              }}

            {:ok, garbage_collect_object_job} ->
              {:ok, %{
                schema_data: schema_data,
                jobs: %{
                  garbage_collect_object: garbage_collect_object_job
                }
              }}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  def abort_upload(bucket, query, params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      abort_upload(bucket, query, schema_data, opts)
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

      * `:action_adapter` - Sets the adapter for database operations. See `Uppy.Adapter.Action`
        module documentation for more information.

      * `:storage_adapter` - Sets the adapter for interfacing with a storage service. See
        `Uppy.Storage` module documentation for more information.

      * `:temporary_object_key_adapter` - Sets the adapter to use for temporary objects. This adapter
        manages the location of temporary object keys. See `Uppy.Adapter.TemporaryObjectKey` module
        documentation for more information.

  ### Examples

      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1}, prefix: "prefix")
      iex> Uppy.Core.start_upload("bucket", 1, {YourSchema, "source"}, %{id: 1})
      iex> Uppy.Core.start_upload("bucket", "unique_id", YourSchema, %{id: 1})
  """
  def start_upload(bucket, partition_id, query, params, opts \\ []) do
    filename = params.filename
    unique_identifier = generate_unique_identifier(params[:unique_identifier], opts)
    basename = basename(unique_identifier, filename)

    key = PathBuilder.temporary_path(%{id: partition_id, basename: basename}, opts)

    create_params =
      Map.merge(params, %{
        unique_identifier: unique_identifier,
        filename: filename,
        key: key
      })

    http_method = upload_http_method(opts)

    with {:ok, presigned_upload} <- Storage.presigned_upload(bucket, http_method, key, opts) do
      operation = fn ->
        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          case queue_abort_upload(
            bucket,
            query,
            schema_data,
            opts
          ) do
            @scheduler_disabled ->
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                presigned_upload: presigned_upload,
                schema_data: schema_data
              }}

            {:ok, abort_upload_job} ->
              {:ok, %{
                unique_identifier: unique_identifier,
                basename: basename,
                key: key,
                presigned_upload: presigned_upload,
                schema_data: schema_data,
                jobs: %{
                  abort_upload: abort_upload_job
                }
              }}

            error -> error
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  defp upload_http_method(opts) do
    opts[:upload_http_method] || @upload_http_method
  end

  defp queue_abort_upload(
    bucket,
    query,
    schema_data,
    opts
  ) do
    if Keyword.get(opts, :scheduler_enabled, true) do
      Scheduler.queue_abort_upload(
        bucket,
        query,
        schema_data.id,
        opts[:schedule][:abort_upload] || @one_hour_seconds,
        opts
      )
    else
      @scheduler_disabled
    end
  end

  defp queue_abort_multipart_upload(
    bucket,
    query,
    schema_data,
    opts
  ) do
    if Keyword.get(opts, :scheduler_enabled, true) do
      Scheduler.queue_abort_multipart_upload(
        bucket,
        query,
        schema_data.id,
        opts[:schedule][:abort_multipart_upload] || @one_hour_seconds,
        opts
      )
    else
      @scheduler_disabled
    end
  end

  defp queue_garbage_collect_object(
    bucket,
    query,
    schema_data,
    opts
  ) do
    if Keyword.get(opts, :scheduler_enabled, true) do
      Scheduler.queue_garbage_collect_object(
        bucket,
        query,
        schema_data.key,
        opts[:schedule][:garbage_collect_object] || @one_hour_seconds,
        opts
      )
    else
      @scheduler_disabled
    end
  end

  defp queue_process_upload(
    pipeline,
    bucket,
    resource,
    query,
    schema_data,
    opts
  ) do
    if Keyword.get(opts, :scheduler_enabled, true) do
      Scheduler.queue_process_upload(
        pipeline,
        bucket,
        resource,
        query,
        schema_data.id,
        opts[:schedule][:process_upload],
        opts
      )
    else
      @scheduler_disabled
    end
  end

  defp generate_unique_identifier(nil, opts) do
    opts
    |> Keyword.get(:unique_identifier_byte_size, @unique_identifier_byte_size)
    |> Utils.generate_unique_identifier()
  end

  defp generate_unique_identifier(unique_identifier, _opts), do: unique_identifier

  defp check_e_tag_is_nil(schema_data) do
    if is_nil(schema_data.e_tag) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden,
        "Expected `:e_tag` to be nil",
        %{schema_data: schema_data}
      )}
    end
  end

  defp check_e_tag_non_nil(schema_data) do
    if is_nil(schema_data.e_tag) === false do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden,
        "Expected `:e_tag` to be non-nil",
        %{schema_data: schema_data}
      )}
    end
  end

  defp check_if_multipart_upload(schema_data) do
    if is_nil(schema_data.upload_id) do
      {:error, Error.call(:forbidden,
        "Expected `:upload_id` to be non-nil",
        %{schema_data: schema_data}
      )}
    else
      {:ok, schema_data}
    end
  end

  defp check_if_non_multipart_upload(schema_data) do
    if is_nil(schema_data.upload_id) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden,
        "Expected `:upload_id` to be nil",
        %{schema_data: schema_data}
      )}
    end
  end
end
