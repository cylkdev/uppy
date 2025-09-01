defmodule Uppy.Core do
  @uid_hash_size 4
  @pending :pending
  @aborted :aborted
  @completed :completed

  defstruct [
    :database,
    :destination_bucket,
    :destination_query,
    :source_bucket,
    :source_query,
    :scheduler,
    :storage
  ]

  def new(opts) do
    %__MODULE__{
      database: opts[:database],
      destination_bucket: opts[:destination_bucket] || opts[:source_bucket],
      destination_query: opts[:destination_query] || opts[:source_query],
      source_bucket: opts[:source_bucket],
      source_query: opts[:source_query],
      scheduler: opts[:scheduler],
      storage: opts[:storage]
    }
  end

  def save_upload(%__MODULE__{} = core, %_{} = src_schema_data, create_params, opts) do
    dest_object = create_params.key

    with {:ok, metadata} <-
           core.storage.describe_object(core.source_bucket, src_schema_data.key, opts),
         {:ok, copy_object_response} <-
           core.storage.copy_object(
             core.destination_bucket || core.source_bucket,
             dest_object,
             core.source_bucket,
             src_schema_data.key,
             opts
           ),
         {:ok, dest_schema_data} <-
           core.database.create(
             core.destination_query,
             Map.merge(create_params, %{
               unique_identifier: create_params[:unique_identifier] || generate_uid(),
               key: dest_object,
               content_length: metadata.content_length,
               content_type: metadata.content_type,
               last_modified: metadata.last_modified,
               etag: metadata.etag,
               pending_upload_id: src_schema_data.id
             }),
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         source_schema_data: src_schema_data,
         destination_schema_data: dest_schema_data,
         copy_object: copy_object_response
       }}
    end
  end

  def save_upload(%__MODULE__{} = core, find_params, create_params, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, find_params, opts) do
      save_upload(core, schema_data, create_params, opts)
    end
  end

  def complete_upload(%__MODULE__{} = core, %_{} = schema_data, update_params, opts) do
    with {:ok, metadata} <-
           core.storage.describe_object(core.source_bucket, schema_data.key, opts) do
      update_params =
        Map.merge(update_params, %{
          state: @completed,
          content_length: metadata.content_length,
          content_type: metadata.content_type,
          last_modified: metadata.last_modified,
          etag: metadata.etag
        })

      fun =
        fn ->
          with {:ok, updated_schema_data} <-
                 core.database.update(core.source_query, schema_data, update_params, opts),
               {:ok, job} <-
                 core.scheduler.enqueue_save_upload(
                   core.source_query,
                   updated_schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               metadata: metadata,
               schema_data: updated_schema_data,
               job: job
             }}
          end
        end

      core.database.transaction(fun, opts)
    end
  end

  def complete_upload(%__MODULE__{} = core, find_params, update_params, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, find_params, opts) do
      complete_upload(core, schema_data, update_params, opts)
    end
  end

  def abort_upload(%__MODULE__{} = core, %_{} = schema_data, update_params, opts) do
    fun =
      fn ->
        with {:ok, updated_schema_data} <-
               core.database.update(
                 core.source_query,
                 schema_data,
                 Map.put(update_params, :state, @aborted),
                 opts
               ),
             {:ok, job} <-
               core.scheduler.enqueue_handle_aborted_upload(
                 core.source_query,
                 updated_schema_data.id,
                 opts
               ) do
          {:ok,
           %{
             schema_data: updated_schema_data,
             job: job
           }}
        end
      end

    core.database.transaction(fun, opts)
  end

  def abort_upload(%__MODULE__{} = core, find_params, update_params, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, find_params, opts) do
      abort_upload(core, schema_data, update_params, opts)
    end
  end

  def start_upload(%__MODULE__{} = core, params, opts) do
    with {:ok, pre_signed_url} <- core.storage.pre_sign(core.source_bucket, params.key, opts) do
      create_params =
        Map.merge(params, %{
          state: @pending,
          key: params.key,
          unique_identifier: params[:unique_identifier] || generate_uid()
        })

      fun =
        fn ->
          with {:ok, schema_data} <- core.database.create(core.source_query, create_params, opts),
               {:ok, job} <-
                 core.scheduler.enqueue_handle_expired_upload(
                   core.source_query,
                   schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               pre_signed_url: pre_signed_url,
               data: schema_data,
               job: job
             }}
          end
        end

      core.database.transaction(fun, opts)
    end
  end

  def find_parts(%__MODULE__{} = core, %_{} = schema_data, opts) do
    with {:ok, parts} <-
           core.storage.list_parts(
             core.source_bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ) do
      {:ok,
       %{
         schema_data: schema_data,
         parts: parts
       }}
    end
  end

  def find_parts(%__MODULE__{} = core, params, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, params, opts) do
      find_parts(core, schema_data, opts)
    end
  end

  def complete_multipart_upload(
        %__MODULE__{} = core,
        %_{} = schema_data,
        update_params,
        parts,
        opts
      ) do
    with {:ok, metadata} <-
           storage_complete_multipart(
             core.storage,
             core.source_bucket,
             schema_data.key,
             schema_data.upload_id,
             parts,
             opts
           ) do
      fun =
        fn ->
          with {:ok, updated_schema_data} <-
                 core.database.update(
                   core.source_query,
                   schema_data,
                   Map.merge(update_params, %{
                     state: @completed,
                     content_length: metadata.content_length,
                     content_type: metadata.content_type,
                     last_modified: metadata.last_modified,
                     etag: metadata.etag
                   }),
                   opts
                 ),
               {:ok, job} <-
                 core.scheduler.enqueue_save_upload(
                   core.source_query,
                   updated_schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               metadata: metadata,
               schema_data: updated_schema_data,
               job: job
             }}
          end
        end

      core.database.transaction(fun, opts)
    end
  end

  def complete_multipart_upload(%__MODULE__{} = core, find_params, update_params, parts, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, find_params, opts) do
      complete_multipart_upload(core, schema_data, update_params, parts, opts)
    end
  end

  def abort_multipart_upload(%__MODULE__{} = core, %_{} = schema_data, update_params, opts) do
    with {:ok, abort_mpu_result} <-
           storage_abort_multipart(
             core.storage,
             core.source_bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ) do
      fun =
        fn ->
          with {:ok, updated_schema_data} <-
                 core.database.update(
                   core.source_query,
                   schema_data,
                   Map.put(update_params, :state, @aborted),
                   opts
                 ),
               {:ok, job} <-
                 core.scheduler.enqueue_handle_aborted_multipart_upload(
                   core.source_query,
                   updated_schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               abort_multipart_upload: abort_mpu_result,
               data: updated_schema_data,
               job: job
             }}
          end
        end

      core.database.transaction(fun, opts)
    end
  end

  def abort_multipart_upload(%__MODULE__{} = core, find_params, update_params, opts) do
    with {:ok, schema_data} <- core.database.find(core.source_query, find_params, opts) do
      abort_multipart_upload(core, schema_data, update_params, opts)
    end
  end

  def start_multipart_upload(%__MODULE__{} = core, params, opts) do
    with {:ok, create_mpu_result} <-
           core.storage.create_multipart_upload(core.source_bucket, params.key, opts) do
      fun =
        fn ->
          with {:ok, schema_data} <-
                 core.database.create(
                   core.source_query,
                   Map.merge(params, %{
                     state: @pending,
                     key: params.key,
                     upload_id: create_mpu_result.upload_id,
                     unique_identifier: params[:unique_identifier] || generate_uid()
                   }),
                   opts
                 ),
               {:ok, job} <-
                 core.scheduler.enqueue_handle_expired_multipart_upload(
                   core.source_query,
                   schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               create_multipart_upload: create_mpu_result,
               schema_data: schema_data,
               job: job
             }}
          end
        end

      core.database.transaction(fun, opts)
    end
  end

  defp storage_complete_multipart(storage, bucket, key, upload_id, parts, opts) do
    case storage.complete_multipart_upload(bucket, key, upload_id, parts, opts) do
      {:ok, _} -> storage.describe_object(bucket, key, opts)
      {:error, %{code: :not_found}} -> storage.describe_object(bucket, key, opts)
      {:error, _} = error -> error
    end
  end

  defp storage_abort_multipart(storage, bucket, key, upload_id, opts) do
    case storage.describe_object(bucket, key, opts) do
      {:error, %{code: :not_found}} ->
        storage.abort_multipart_upload(
          bucket,
          key,
          upload_id,
          opts
        )

      {:ok, metadata} ->
        {:error,
         ErrorMessage.bad_request("multipart upload completed.", %{
           metadata: metadata,
           bucket: bucket,
           key: key,
           upload_id: upload_id
         })}
    end
  end

  defp generate_uid do
    @uid_hash_size |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)
  end
end
