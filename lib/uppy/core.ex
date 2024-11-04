defmodule Uppy.Core do
  @moduledoc """

  :pending, # created and waiting to be uploaded / in progress
  :available, # object exists in storage and has been confirmed, e_tag is set
  :processing, # post processing started by a job
  :completed, # post processing complete and moved to permanent path
  :discarded, # system event marked it as stale
  :cancelled
  """

  alias Uppy.{
    DBAction,
    Error,
    Pipeline,
    Scheduler,
    Storage
  }

  @stale_states [:discarded, :cancelled]

  @doc """
  ...
  """
  def process_upload(
    %_{} = resolution,
    pipeline,
    opts
  ) do
    phases =
      case pipeline do
        phases when is_list(phases) -> phases
        module when is_atom(module) and (not is_nil(module)) -> module.phases(opts)
        _ -> Uppy.PostProcessingPipeline.phases(opts)
      end

    with {:ok, resolution, done} <- Pipeline.run(resolution, phases) do
      {:ok, %{
        resolution: resolution,
        done: done
      }}
    end
  end

  def process_upload(
    bucket,
    destination_object,
    query,
    %_{} = schema_data,
    pipeline,
    opts
  ) do
    Uppy.Resolution
    |> struct!(
      bucket: bucket,
      context: %{destination_object: destination_object},
      query: query,
      value: schema_data
    )
    |> process_upload(pipeline, opts)
  end

  def process_upload(
    bucket,
    destination_object,
    query,
    params,
    pipeline,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      process_upload(
        bucket,
        destination_object,
        query,
        schema_data,
        pipeline,
        opts
      )
    end
  end

  @doc """
  ...
  """
  def delete_object_and_upload(bucket, _query, %_{} = schema_data, opts) do
    case Storage.head_object(bucket, schema_data.key, opts) do
      {:ok, metadata} ->
        with {:ok, _} <- Storage.delete_object(bucket, schema_data.key, opts),
          {:ok, schema_data} <- DBAction.delete(schema_data, opts) do
          {:ok, %{
            metadata: metadata,
            schema_data: schema_data
          }}
        end

      {:error, %{code: :not_found}} ->
        with {:ok, schema_data} <- DBAction.delete(schema_data, opts) do
          {:ok, %{schema_data: schema_data}}
        end

      {:error, _} = error ->
        error

    end
  end

  def delete_object_and_upload(bucket, query, find_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      delete_object_and_upload(bucket, query, schema_data, opts)
    end
  end

  ## Non-Multipart API

  @doc """
  ...
  """
  def soft_delete_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    update_params = Map.put(update_params, :state, :cancelled)

    with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts),
      {:ok, delete_object_and_upload_job} <-
        Scheduler.queue_delete_object_and_upload(
          bucket,
          query,
          schema_data.id,
          opts
        ) do
      {:ok, %{
        schema_data: schema_data,
        jobs: %{
          delete_object_and_upload: delete_object_and_upload_job
        }
      }}
    end
  end

  def soft_delete_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      soft_delete_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  @doc """
  ...
  """
  def complete_upload(
    bucket,
    destination_object,
    query,
    %_{} = schema_data,
    update_params,
    opts
  ) do
    if schema_data.upload_id do
      {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
        schema_data: schema_data,
        query: query,
        bucket: bucket
      })}
    else
      case Storage.head_object(bucket, schema_data.key, opts) do
        {:ok, metadata} ->
          do_complete_upload(
            bucket,
            destination_object,
            query,
            schema_data,
            update_params,
            metadata,
            opts
          )

        {:error, _} = error ->
          error

      end
    end
  end

  def complete_upload(
    bucket,
    destination_object,
    query,
    find_params,
    update_params,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_upload(
        bucket,
        destination_object,
        query,
        schema_data,
        update_params,
        opts
      )
    end
  end

  defp do_complete_upload(
    bucket,
    destination_object,
    query,
    schema_data,
    update_params,
    metadata,
    opts
  ) do
    operation =
      fn ->
        update_params =
          Map.merge(update_params, %{
            state: :available,
            e_tag: metadata.e_tag
          })

        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, process_upload_job} <-
              Scheduler.queue_process_upload(
                bucket,
                destination_object,
                query,
                schema_data.id,
                opts[:pipeline],
                opts
              ) do
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data,
                jobs: %{
                  process_upload: process_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

    DBAction.transaction(operation, opts)
  end

  @doc """
  ...
  """
  def abort_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    if schema_data.upload_id do
      {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
        schema_data: schema_data,
        query: query,
        bucket: bucket
      })}
    else
      do_abort_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def abort_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  defp do_abort_upload(bucket, query, schema_data, update_params, opts) do
    state = opts[:state] || :cancelled

    unless state in @stale_states do
      raise ArgumentError, "Expected state to be one of #{inspect(@stale_states)}"
    end

    update_params = Map.put(update_params, :state, state)

    operation =
      fn ->
        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, delete_object_and_upload_job} <-
              Scheduler.queue_delete_object_and_upload(
                bucket,
                query,
                schema_data.id,
                opts
              ) do
              {:ok, %{
                schema_data: schema_data,
                jobs: %{
                  delete_object_and_upload: delete_object_and_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

    DBAction.transaction(operation, opts)
  end

  @doc """
  ...
  """
  def start_upload(bucket, destination_object, query, create_params, opts) do
    create_params =
      Map.merge(create_params, %{
        state: :pending,
        key: destination_object
      })

    with {:ok, presigned_upload} <- Storage.presigned_upload(bucket, destination_object, opts) do
      operation = fn ->
        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, abort_upload_job} <-
              Scheduler.queue_abort_upload(
                bucket,
                query,
                schema_data.id,
                opts
              ) do
              {:ok, %{
                presigned_upload: presigned_upload,
                schema_data: schema_data,
                jobs: %{
                  abort_upload: abort_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end

  ## Multipart API

  @doc """
  ...
  """
  def find_parts(
    bucket,
    _query,
    %_{} = schema_data,
    next_part_number_marker,
    opts
  ) do
    if is_nil(schema_data.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_data: schema_data
      })}
    else
      with {:ok, parts} <-
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
  end

  def find_parts(bucket, query, find_params, next_part_number_marker, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_data, next_part_number_marker, opts)
    end
  end

  @doc """
  ...
  """
  def presigned_part(bucket, query, %_{} = schema_data, part_number, opts) do
    if is_nil(schema_data.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        bucket: bucket,
        query: query,
        schema_data: schema_data,
        part_number: part_number
      })}
    else
      with {:ok, presigned_part} <-
          Storage.presigned_part_upload(
            bucket,
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
  end

  def presigned_part(bucket, query, params, part_number, opts) do
    with {:ok, schema_data} <- DBAction.find(query, params, opts) do
      presigned_part(bucket, query, schema_data, part_number, opts)
    end
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
    bucket,
    destination_object,
    query,
    %_{} = schema_data,
    update_params,
    parts,
    opts
  ) do
    if is_nil(schema_data.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_data: schema_data,
        query: query
      })}
    else
      with {:ok, metadata} <-
        storage_complete_multipart_upload(
          bucket,
          schema_data,
          parts,
          opts
        ) do
        do_complete_multipart_upload(
          bucket,
          destination_object,
          query,
          schema_data,
          update_params,
          metadata,
          opts
        )
      end
    end
  end

  def complete_multipart_upload(
    bucket,
    destination_object,
    query,
    find_params,
    update_params,
    parts,
    opts
  ) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        destination_object,
        query,
        schema_data,
        update_params,
        parts,
        opts
      )
    end
  end

  defp do_complete_multipart_upload(
    bucket,
    destination_object,
    query,
    schema_data,
    update_params,
    metadata,
    opts
  ) do
    operation =
      fn ->
        update_params =
          Map.merge(update_params, %{
            state: :available,
            e_tag: metadata.e_tag
          })

        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, process_upload_job} <-
              Scheduler.queue_process_upload(
                bucket,
                destination_object,
                query,
                schema_data.id,
                opts[:pipeline],
                opts
              ) do
              {:ok, %{
                metadata: metadata,
                schema_data: schema_data,
                jobs: %{
                  process_upload: process_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

    DBAction.transaction(operation, opts)
  end

  defp storage_complete_multipart_upload(
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
  ...
  """
  def abort_multipart_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    if is_nil(schema_data.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_data: schema_data,
        query: query
      })}
    else
      case Storage.abort_multipart_upload(bucket, schema_data.key, schema_data.upload_id, opts) do
        {:ok, metadata} ->
          with {:ok, res} <-
            do_abort_multipart_upload(
              bucket,
              query,
              schema_data,
              update_params,
              opts
            ) do
            {:ok, Map.put(res, :metadata, metadata)}
          end

        {:error, %{code: :not_found}} ->
          do_abort_multipart_upload(
            bucket,
            query,
            schema_data,
            update_params,
            opts
          )

        {:error, _} = error ->
          error

      end
    end
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  defp do_abort_multipart_upload(
    bucket,
    query,
    schema_data,
    update_params,
    opts
  ) do
    operation =
      fn ->
        state = opts[:state] || :cancelled

        unless state in @stale_states do
          raise ArgumentError, "Expected state to be one of #{inspect(@stale_states)}"
        end

        update_params = Map.put(update_params, :state, state)

        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, delete_object_and_upload_job} <-
              Scheduler.queue_delete_object_and_upload(
                bucket,
                query,
                schema_data.id,
                opts
              ) do
              {:ok, %{
                schema_data: schema_data,
                jobs: %{
                  delete_object_and_upload: delete_object_and_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

    DBAction.transaction(operation, opts)
  end

  @doc """
  ...
  """
  def start_multipart_upload(bucket, destination_object, query, create_params, opts) do
    with {:ok, multipart_upload} <- Storage.initiate_multipart_upload(bucket, destination_object, opts) do
      operation = fn ->
        create_params =
          Map.merge(create_params, %{
            state: :pending,
            upload_id: multipart_upload.upload_id,
            key: destination_object
          })

        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, abort_multipart_upload_job} <-
              Scheduler.queue_abort_multipart_upload(
                bucket,
                query,
                schema_data.id,
                opts
              ) do
              {:ok, %{
                multipart_upload: multipart_upload,
                schema_data: schema_data,
                jobs: %{
                  abort_multipart_upload: abort_multipart_upload_job
                }
              }}
            end
          else
            raise "not implemented"
          end
        end
      end

      DBAction.transaction(operation, opts)
    end
  end
end
