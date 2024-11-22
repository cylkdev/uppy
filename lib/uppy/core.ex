defmodule Uppy.Core do
  @moduledoc """
  """

  alias Uppy.{
    DBAction,
    Pipeline,
    Storage
  }

  def process_upload(
        bucket,
        query,
        %_{} = schema_data,
        module_or_phases,
        context,
        opts
      ) do
    resolution =
      struct!(Uppy.Resolution, %{
        bucket: bucket,
        context: context,
        query: query,
        value: schema_data
      })

    phases =
      case module_or_phases do
        phases when is_list(phases) -> phases
        module -> module.phases(opts)
      end

    with {:ok, resolution, done} <- Pipeline.run(resolution, phases) do
      {:ok,
       %{
         resolution: resolution,
         done: done
       }}
    end
  end

  def process_upload(
        bucket,
        query,
        params,
        module_or_phases,
        context,
        opts
      ) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      process_upload(
        bucket,
        query,
        schema_data,
        module_or_phases,
        context,
        opts
      )
    end
  end

  def find_parts(
        bucket,
        _query,
        %_{} = schema_data,
        opts
      ) do
    with {:ok, parts} <-
           Storage.list_parts(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ) do
      {:ok,
       %{
         parts: parts,
         schema_data: schema_data
       }}
    end
  end

  def find_parts(bucket, query, find_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_data, opts)
    end
  end

  def presigned_part(bucket, _query, %_{} = schema_data, part_number, opts) do
    with {:ok, presigned_part} <-
           Storage.presigned_part_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
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

  def complete_multipart_upload(
        bucket,
        query,
        %_{} = schema_data,
        update_params,
        parts,
        opts
      ) do
    with {:ok, metadata} <-
           complete_multipart_upload_and_head_object(
             bucket,
             schema_data,
             parts,
             opts
           ),
         {:ok, schema_data} <-
           DBAction.update(
             query,
             schema_data,
             Map.put(update_params, :e_tag, metadata.e_tag),
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def complete_multipart_upload(
        bucket,
        query,
        find_params,
        update_params,
        parts,
        opts
      ) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        query,
        schema_data,
        update_params,
        parts,
        opts
      )
    end
  end

  defp complete_multipart_upload_and_head_object(
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

  def abort_multipart_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    with {:ok, metadata} <-
           Storage.abort_multipart_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ),
         {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def start_multipart_upload(bucket, query, create_params, opts) do
    key = URI.encode(create_params.key)

    create_params = Map.put(create_params, :key, key)

    with {:ok, multipart_upload} <- Storage.initiate_multipart_upload(bucket, key, opts),
         {:ok, schema_data} <-
           DBAction.create(
             query,
             Map.put(create_params, :upload_id, multipart_upload.upload_id),
             opts
           ) do
      {:ok,
       %{
         multipart_upload: multipart_upload,
         schema_data: schema_data
       }}
    end
  end

  def confirm_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    with {:ok, metadata} <- Storage.head_object(bucket, schema_data.key, opts),
         {:ok, schema_data} <-
           DBAction.update(
             query,
             schema_data,
             Map.put(update_params, :e_tag, metadata.e_tag),
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def confirm_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      confirm_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def abort_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    case Storage.head_object(bucket, schema_data.key, opts) do
      {:ok, metadata} ->
        {:error,
         ErrorMessage.forbidden("not in progress", %{
           bucket: bucket,
           query: query,
           schema_data: schema_data,
           metadata: metadata
         })}

      {:error, %{code: :not_found}} ->
        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          {:ok, %{schema_data: schema_data}}
        end

      e ->
        e
    end
  end

  def abort_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def start_upload(bucket, query, create_params, opts) do
    key = URI.encode(create_params.key)

    create_params = Map.put(create_params, :key, key)

    with {:ok, presigned_upload} <- Storage.presigned_upload(bucket, key, opts),
         {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
      {:ok,
       %{
         presigned_upload: presigned_upload,
         schema_data: schema_data
       }}
    end
  end
end
