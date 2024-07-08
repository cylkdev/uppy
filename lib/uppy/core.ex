defmodule Uppy.Core do
  @moduledoc false

  alias Uppy.{
    Actions,
    Config,
    Error,
    Pipeline,
    Storage,
    TemporaryScopes,
    Utils
  }

  @unique_identifier_bytes_size 32

  def presigned_part(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        schema,
        params,
        part_number,
        options
      ) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
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

  def find_parts(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        schema,
        params,
        maybe_next_part_number_marker,
        options
      ) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
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

  def confirm_multipart_upload(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        schema,
        params,
        parts,
        options
      ) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, metadata} <-
           Storage.confirm_multipart_upload(
             storage_adapter,
             bucket,
             schema_data.key,
             schema_data.upload_id,
             parts,
             options
           ),
         {:ok, schema_data} <-
           actions_update(schema, schema_data, %{e_tag: metadata.e_tag}, options) do
      {:ok,
       %{
         multipart: true,
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def abort_multipart_upload(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, abort_multipart_upload_payload} <-
           handle_abort_multipart_upload(
             storage_adapter,
             bucket,
             schema_data.key,
             schema_data.upload_id,
             options
           ),
         {:ok, schema_data} <- actions_delete(schema_data, options) do
      {:ok, Map.put(abort_multipart_upload_payload, :schema_data, schema_data)}
    end
  end

  defp handle_abort_multipart_upload(storage, bucket, key, upload_id, options) do
    case Storage.abort_multipart_upload(storage, bucket, key, upload_id, options) do
      {:ok, metadata} -> {:ok, %{metadata: metadata}}
      {:error, %{code: :not_found}} -> {:ok, %{}}
      error -> error
    end
  end

  def start_multipart_upload(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        partition_id,
        schema,
        params,
        options
      ) do
    filename = params.filename

    unique_identifier =
      Map.get(
        params,
        :unique_identifier,
        Utils.generate_unique_identifier(@unique_identifier_bytes_size)
      )

    basename = basename(unique_identifier, filename)

    key =
      TemporaryScopes.prefix(
        temporary_scope_adapter,
        to_string(partition_id),
        basename
      )

    with {:ok, multipart_upload} <-
           Storage.initiate_multipart_upload(storage_adapter, bucket, key, options),
         {:ok, schema_data} <-
           actions_create(
             schema,
             Map.merge(params, %{
               upload_id: multipart_upload.upload_id,
               unique_identifier: unique_identifier,
               filename: filename,
               key: key
             }),
             options
           ) do
      {:ok,
       %{
         unique_identifier: unique_identifier,
         key: key,
         multipart_upload: multipart_upload,
         schema_data: schema_data
       }}
    end
  end

  def run_pipeline(
        pipeline,
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        permanent_scope_adapter,
        resource_name,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <-
           find_confirmed_upload(temporary_scope_adapter, schema, params, options) do
      input = %{
        actions_adapter: Config.actions_adapter(),
        storage_adapter: storage_adapter,
        bucket: bucket,
        resource_name: resource_name,
        temporary_scope_adapter: temporary_scope_adapter,
        permanent_scope_adapter: permanent_scope_adapter,
        schema_data: schema_data,
        private: %{},
        options: options
      }

      with {:ok, result, done} <- Pipeline.run(input, pipeline) do
        {:ok,
         %{
           result: result,
           phases: done
         }}
      end
    end
  end

  def confirm_upload(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_non_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ) do
      find_upload_object_and_update_e_tag(storage_adapter, bucket, schema, schema_data, options)
    end
  end

  def find_upload_object_and_update_e_tag(
        storage_adapter,
        bucket,
        schema,
        %_{} = schema_data,
        options
      ) do
    with {:ok, metadata} <-
           Storage.head_object(storage_adapter, bucket, schema_data.key, options),
         {:ok, schema_data} <-
           actions_update(
             schema,
             schema_data,
             %{e_tag: metadata.e_tag},
             options
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def find_upload_object_and_update_e_tag(storage_adapter, bucket, schema, params, options) do
    with {:ok, schema_data} <- actions_find(schema, params, options) do
      find_upload_object_and_update_e_tag(storage_adapter, bucket, schema, schema_data, options)
    end
  end

  def garbage_collect_object(storage_adapter, bucket, schema, key, options) do
    with :ok <- ensure_not_found(schema, %{key: key}, options),
         {:ok, _} <- Storage.head_object(storage_adapter, bucket, key, options),
         {:ok, _} <- Storage.delete_object(storage_adapter, bucket, key, options) do
      :ok
    else
      {:error, %{code: :not_found}} -> :ok
      error -> error
    end
  end

  defp ensure_not_found(schema, params, options) do
    case actions_find(schema, params, options) do
      {:ok, schema_data} ->
        details = %{
          schema: schema,
          params: params,
          schema_data: schema_data
        }

        {:error, Error.call(:forbidden, "record found", details, options)}

      {:error, %{code: :not_found}} ->
        :ok

      error ->
        error
    end
  end

  def abort_upload(temporary_scope_adapter, schema, params, options) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options),
         {:ok, schema_data} <-
           check_if_non_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, schema_data} <- actions_delete(schema_data, options) do
      {:ok, %{schema_data: schema_data}}
    end
  end

  def find_permanent_upload(temporary_scope_adapter, schema, params, options) do
    with {:ok, schema_data} <- actions_find(schema, params, options) do
      if TemporaryScopes.path?(temporary_scope_adapter, schema_data.key) === false do
        {:ok, schema_data}
      else
        details = %{
          schema: schema,
          schema_data: schema_data,
          params: params
        }

        {:error, Error.call(:forbidden, "not a permanent upload", details, options)}
      end
    end
  end

  def find_confirmed_upload(temporary_scope_adapter, schema, params, options) do
    with {:ok, schema_data} <-
           find_temporary_upload(temporary_scope_adapter, schema, params, options) do
      if is_nil(schema_data.e_tag) === false do
        {:ok, schema_data}
      else
        details = %{
          schema: schema,
          schema_data: schema_data,
          params: params
        }

        {:error, Error.call(:forbidden, "upload incomplete", details, options)}
      end
    end
  end

  def find_temporary_upload(temporary_scope_adapter, schema, params, options) do
    with {:ok, schema_data} <- actions_find(schema, params, options) do
      if TemporaryScopes.path?(temporary_scope_adapter, schema_data.key) do
        {:ok, schema_data}
      else
        details = %{
          schema: schema,
          schema_data: schema_data,
          params: params
        }

        {:error, Error.call(:forbidden, "not a temporary upload", details, options)}
      end
    end
  end

  def start_upload(
        storage_adapter,
        bucket,
        temporary_scope_adapter,
        partition_id,
        schema,
        params,
        options
      ) do
    filename = params.filename

    unique_identifier =
      Map.get(
        params,
        :unique_identifier,
        Utils.generate_unique_identifier(@unique_identifier_bytes_size)
      )

    basename = basename(unique_identifier, filename)

    key =
      TemporaryScopes.prefix(
        temporary_scope_adapter,
        to_string(partition_id),
        basename
      )

    with {:ok, presigned_upload} <-
           Storage.presigned_upload(storage_adapter, bucket, key, options),
         {:ok, schema_data} <-
           actions_create(
             schema,
             Map.merge(params, %{
               unique_identifier: unique_identifier,
               filename: filename,
               key: key
             }),
             options
           ) do
      {:ok,
       %{
         unique_identifier: unique_identifier,
         key: key,
         presigned_upload: presigned_upload,
         schema_data: schema_data
       }}
    end
  end

  defp basename(unique_identifier, path), do: "#{unique_identifier}-#{path}"

  defp check_if_multipart_upload(schema_data, details, options) do
    if has_upload_id?(schema_data) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden, "must be a multipart upload", details, options)}
    end
  end

  defp check_if_non_multipart_upload(schema_data, details, options) do
    if has_upload_id?(schema_data) do
      {:error, Error.call(:forbidden, "must be a non multipart upload", details, options)}
    else
      {:ok, schema_data}
    end
  end

  defp has_upload_id?(%{upload_id: nil}), do: false
  defp has_upload_id?(%{upload_id: _upload_id}), do: true

  defp actions_create(schema, params, options) do
    Actions.create(Config.actions_adapter(), schema, params, options)
  end

  defp actions_find(schema, params, options) do
    Actions.find(Config.actions_adapter(), schema, params, options)
  end

  defp actions_update(schema, schema_data, params, options) do
    Actions.update(Config.actions_adapter(), schema, schema_data, params, options)
  end

  defp actions_delete(schema_data, options) do
    Actions.delete(Config.actions_adapter(), schema_data, options)
  end
end
