defmodule Uppy.Core do
  @moduledoc false

  alias Uppy.{Action, ObjectStore}

  def all_ingested_uploads(schema, params, opts) do
    Action.all_records(schema, Map.put(params, :state, :processed), opts)
  end

  def all_pending_uploads(schema, params, opts) do
    Action.all_records(schema, Map.put(params, :state, [:pending, :completed, :processing]), opts)
  end

  def complete_upload(bucket, schema, request_key, find_params, update_params, opts) do
    with {:ok, schema_data} <-
           Action.find_record(schema, Map.put(find_params, :request_key, request_key), opts),
         {:ok, metadata} <- ObjectStore.head_object(bucket, schema_data.request_key, opts),
         {:ok, schema_data} <-
           Action.update_record(
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
           Action.find_record(schema, Map.put(find_params, :request_key, request_key), opts) do
      case ObjectStore.head_object(bucket, schema_data.request_key, opts) do
        {:ok, _} ->
          with {:ok, _} <- ObjectStore.delete_object(bucket, schema_data.request_key, opts),
               {:ok, schema_data} <-
                 Action.update_record(
                   schema,
                   schema_data,
                   Map.put(update_params, :state, :aborted),
                   opts
                 ) do
            {:ok, schema_data}
          end

        {:error, _} ->
          with {:ok, schema_data} <-
                 Action.update_record(
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
           Action.find_record(schema, Map.put(params, :request_key, request_key), opts),
         {:ok, pre_signed_url} <- ObjectStore.pre_sign(bucket, schema_data.request_key, opts) do
      {:ok,
       %{
         schema_data: schema_data,
         pre_signed_url: pre_signed_url
       }}
    end
  end

  def create_upload(bucket, schema, stored_key, request_key, filename, params, opts) do
    with {:ok, schema_data} <-
           Action.create_record(
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
           Action.find_record(schema, Map.put(params, :request_key, request_key), opts),
         {:ok, parts} <- ObjectStore.list_parts(bucket, schema_data.request_key, upload_id, opts) do
      {:ok,
       %{
         schema_data: schema_data,
         parts: parts
       }}
    end
  end

  def pre_sign_part(bucket, schema, request_key, upload_id, part_number, params, opts) do
    with {:ok, schema_data} <-
           Action.find_record(schema, Map.put(params, :request_key, request_key), opts),
         {:ok, pre_signed_url} <-
           ObjectStore.pre_sign_part(
             bucket,
             schema_data.request_key,
             upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
         schema_data: schema_data,
         pre_signed_url: pre_signed_url
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
    with {:ok, schema_data} <-
           Action.find_record(schema, Map.put(find_params, :request_key, request_key), opts) do
      parts =
        Enum.map(parts, fn
          {part_number, etag} -> {part_number, etag}
          item -> {item.part_number, item.etag}
        end)

      with {:ok, _} <-
             ObjectStore.complete_multipart_upload(
               bucket,
               schema_data.request_key,
               upload_id,
               parts,
               opts
             ),
           {:ok, metadata} <- ObjectStore.head_object(bucket, schema_data.request_key, opts),
           {:ok, schema_data} <-
             Action.update_record(
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
      else
        {:error, %{code: :not_found}} ->
          with {:ok, metadata} <- ObjectStore.head_object(bucket, schema_data.request_key, opts),
               {:ok, schema_data} <-
                 Action.update_record(
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

        {:error, reason} ->
          {:error, reason}
      end
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
           Action.find_record(schema, Map.put(find_params, :request_key, request_key), opts) do
      case ObjectStore.abort_multipart_upload(bucket, schema_data.request_key, upload_id, opts) do
        {:ok, _} ->
          with {:ok, schema_data} <-
                 Action.update_record(
                   schema,
                   schema_data,
                   Map.put(update_params, :state, :aborted),
                   opts
                 ) do
            {:ok, schema_data}
          end

        {:error, %{code: :not_found}} ->
          case ObjectStore.head_object(bucket, schema_data.request_key, opts) do
            {:ok, metadata} ->
              {:error,
               ErrorMessage.bad_request("upload completed", %{
                 schema_data: schema_data,
                 metadata: metadata
               })}

            {:error, _} ->
              with {:ok, schema_data} <-
                     Action.update_record(
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
           ObjectStore.create_multipart_upload(bucket, request_key, opts),
         {:ok, schema_data} <-
           Action.create_record(
             schema,
             Map.merge(params, %{
               state: :pending,
               filename: filename,
               request_key: request_key,
               stored_key: stored_key
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
