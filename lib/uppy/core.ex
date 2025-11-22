defmodule Uppy.Core do
  @moduledoc false

  alias Uppy.{Action, Store}

  def all_ingested_uploads(schema, params, opts) do
    Action.all_schema_datas(schema, Map.put(params, :state, :processed), opts)
  end

  def all_pending_uploads(schema, params, opts) do
    Action.all_schema_datas(
      schema,
      Map.put(params, :state, [:pending, :completed, :processing]),
      opts
    )
  end

  def complete_upload(bucket, schema, request_key, find_params, update_params, opts) do
    with {:ok, schema_data} <-
           Action.find_schema_data(schema, Map.put(find_params, :request_key, request_key), opts),
         {:ok, metadata} <- Store.head_object(bucket, schema_data.request_key, opts),
         {:ok, schema_data} <-
           Action.update_schema_data(
             schema,
             schema_data,
             Map.merge(update_params, %{
               state: :completed,
               content_length: metadata.content_length,
               content_type: metadata.content_type,
               last_modified: metadata.last_modified,
               etag: metadata.etag
             }),
             opts
           ) do
      {:ok, schema_data}
    end
  end

  def abort_upload(bucket, schema, request_key, find_params, update_params, opts) do
    with {:ok, schema_data} <-
           Action.find_schema_data(schema, Map.put(find_params, :request_key, request_key), opts) do
      case Store.head_object(bucket, schema_data.request_key, opts) do
        {:ok, _} ->
          with {:ok, _} <- Store.delete_object(bucket, schema_data.request_key, opts),
               {:ok, schema_data} <-
                 Action.update_schema_data(
                   schema,
                   schema_data,
                   Map.put(update_params, :state, :aborted),
                   opts
                 ) do
            {:ok, schema_data}
          end

        {:error, _} ->
          with {:ok, schema_data} <-
                 Action.update_schema_data(
                   schema,
                   schema_data,
                   Map.put(update_params, :state, :aborted),
                   opts
                 ) do
            {:ok, schema_data}
          end
      end
    end
  end

  def pre_sign(bucket, schema, request_key, params, opts) do
    with {:ok, schema_data} <-
           Action.find_schema_data(schema, Map.put(params, :request_key, request_key), opts),
         signed_post <- Store.pre_sign_post(bucket, schema_data.request_key, opts) do
      {:ok,
       %{
         schema_data: schema_data,
         signed_post: signed_post
       }}
    end
  end

  def create_upload(bucket, schema, stored_key, request_key, filename, params, opts) do
    with {:ok, schema_data} <-
           Action.create_schema_data(
             schema,
             Map.merge(params, %{
               state: :pending,
               bucket: bucket,
               stored_key: stored_key,
               request_key: request_key,
               filename: filename
             }),
             opts
           ) do
      {:ok, schema_data}
    end
  end

  def find_parts(bucket, schema, request_key, upload_id, params, opts) do
    with {:ok, schema_data} <-
           Action.find_schema_data(
             schema,
             Map.merge(params, %{
               request_key: request_key,
               upload_id: upload_id
             }),
             opts
           ),
         {:ok, parts} <- Store.list_parts(bucket, schema_data.request_key, upload_id, opts) do
      {:ok,
       %{
         schema_data: schema_data,
         parts: parts
       }}
    end
  end

  def pre_sign_part(bucket, schema, request_key, upload_id, part_number, params, opts) do
    with {:ok, schema_data} <-
           Action.find_schema_data(
             schema,
             Map.merge(params, %{
               request_key: request_key,
               upload_id: upload_id
             }),
             opts
           ),
         signed_post <-
           Store.pre_sign_part(
             bucket,
             schema_data.request_key,
             upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
         schema_data: schema_data,
         signed_post: signed_post
       }}
    end
  end

  def complete_multipart_upload(
        bucket,
        schema,
        request_key,
        upload_id,
        parts,
        find_params,
        update_params,
        opts
      ) do
    find_params = Map.merge(find_params, %{request_key: request_key, upload_id: upload_id})
    parts = normalize_parts(parts)
    max_size = Keyword.fetch!(opts, :max_size)

    with {:ok, schema_data} <- Action.find_schema_data(schema, find_params, opts) do
      with :ok <-
             verify_parts_size_limit(bucket, schema_data.request_key, upload_id, max_size, opts),
           {:ok, _} <-
             Store.complete_multipart_upload(
               bucket,
               schema_data.request_key,
               upload_id,
               parts,
               opts
             ) do
        complete_mpu(bucket, schema, schema_data, update_params, opts)
      else
        {:error, %{code: :not_found}} ->
          complete_mpu(bucket, schema, schema_data, update_params, opts)

        {:error, {:max_size_exceeded, total_size}} ->
          case Store.abort_multipart_upload(bucket, schema_data.request_key, upload_id, opts) do
            {:ok, _} ->
              handle_mpu_exceeded_max_size(schema, schema_data, total_size, max_size, opts)

            {:error, _} ->
              handle_mpu_exceeded_max_size(schema, schema_data, total_size, max_size, opts)
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp normalize_parts(parts) do
    Enum.map(parts, fn
      {part_number, etag} -> {part_number, etag}
      item -> {item.part_number, item.etag}
    end)
  end

  defp handle_mpu_exceeded_max_size(schema, schema_data, total_size, max_size, opts) do
    with {:ok, schema_data} <-
           Action.update_schema_data(
             schema,
             schema_data,
             %{state: :aborted},
             opts
           ) do
      ErrorMessage.bad_request("multipart upload exceeded max size", %{
        total_size: total_size,
        max_size: max_size,
        schema_data: schema_data
      })
    end
  end

  defp complete_mpu(bucket, schema, schema_data, update_params, opts) do
    with {:ok, metadata} <- Store.head_object(bucket, schema_data.request_key, opts),
         {:ok, schema_data} <-
           Action.update_schema_data(
             schema,
             schema_data,
             Map.merge(update_params, %{
               state: :completed,
               content_length: metadata.content_length,
               content_type: metadata.content_type,
               last_modified: metadata.last_modified,
               etag: metadata.etag
             }),
             opts
           ) do
      {:ok, schema_data}
    end
  end

  defp verify_parts_size_limit(bucket, request_key, upload_id, max_size, opts) do
    if Keyword.has_key?(opts, :max_size) do
      with {:ok, parts} <- Store.list_parts(bucket, request_key, upload_id, opts) do
        total_size = Enum.reduce(parts, 0, fn part, acc -> acc + part.size end)

        if total_size > max_size do
          {:error, {:max_size_exceeded, total_size}}
        else
          :ok
        end
      end
    else
      :ok
    end
  end

  def abort_multipart_upload(
        bucket,
        schema,
        request_key,
        upload_id,
        find_params,
        update_params,
        opts
      ) do
    with {:ok, schema_data} <-
           Action.find_schema_data(
             schema,
             Map.merge(find_params, %{
               request_key: request_key,
               upload_id: upload_id
             }),
             opts
           ) do
      case Store.abort_multipart_upload(bucket, schema_data.request_key, upload_id, opts) do
        {:ok, _} ->
          with {:ok, schema_data} <-
                 Action.update_schema_data(
                   schema,
                   schema_data,
                   Map.put(update_params, :state, :aborted),
                   opts
                 ) do
            {:ok, schema_data}
          end

        {:error, %{code: :not_found}} ->
          case Store.head_object(bucket, schema_data.request_key, opts) do
            {:ok, metadata} ->
              {:error,
               ErrorMessage.bad_request("upload completed", %{
                 schema_data: schema_data,
                 metadata: metadata
               })}

            {:error, _} ->
              with {:ok, schema_data} <-
                     Action.update_schema_data(
                       schema,
                       schema_data,
                       Map.put(update_params, :state, :aborted),
                       opts
                     ) do
                {:ok, schema_data}
              end
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def create_multipart_upload(bucket, schema, stored_key, request_key, filename, params, opts) do
    with {:ok, multipart_upload} <-
           Store.create_multipart_upload(bucket, request_key, opts),
         {:ok, schema_data} <-
           Action.create_schema_data(
             schema,
             Map.merge(params, %{
               state: :pending,
               filename: filename,
               request_key: request_key,
               stored_key: stored_key,
               upload_id: multipart_upload.upload_id
             }),
             opts
           ) do
      {:ok,
       %{
         schema_data: schema_data,
         multipart_upload: multipart_upload
       }}
    end
  end
end
