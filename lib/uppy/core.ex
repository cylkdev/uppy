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
    %_{} = schema_struct,
    pipeline,
    opts
  ) do
    Uppy.Resolution
    |> struct!(
      bucket: bucket,
      context: %{destination_object: destination_object},
      query: query,
      value: schema_struct
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
    with {:ok, schema_struct} <- DBAction.find(query, params, opts) do
      process_upload(
        bucket,
        destination_object,
        query,
        schema_struct,
        pipeline,
        opts
      )
    end
  end

  @doc """
  ...
  """
  def delete_object_and_upload(bucket, _query, %_{} = schema_struct, opts) do
    if schema_struct.state in [:discarded, :cancelled] do
      case Storage.head_object(bucket, schema_struct.key, opts) do
        {:ok, metadata} ->
          with {:ok, _} <- Storage.delete_object(bucket, schema_struct.key, opts),
            {:ok, schema_struct} <- DBAction.delete(schema_struct, opts) do
            {:ok, %{
              metadata: metadata,
              schema_struct: schema_struct
            }}
          end

        {:error, %{code: :not_found}} ->
          with {:ok, schema_struct} <- DBAction.delete(schema_struct, opts) do
            {:ok, %{schema_struct: schema_struct}}
          end

        {:error, _} = error ->
          error

      end
    else
      {:error, Error.call(:forbidden, "expected a state of discarded or cancelled", %{
        bucket: bucket,
        schema_struct: schema_struct
      })}
    end
  end

  def delete_object_and_upload(bucket, query, find_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      delete_object_and_upload(bucket, query, schema_struct, opts)
    end
  end

  ## Non-Multipart API

  @doc """
  ...
  """
  def schedule_delete_object_and_upload(bucket, query, %_{} = schema_struct, update_params, opts) do
    update_params = Map.put(update_params, :state, :cancelled)

    with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts),
      {:ok, delete_object_and_upload_job} <-
        Scheduler.queue_delete_object_and_upload(
          bucket,
          query,
          schema_struct.id,
          opts
        ) do
      {:ok, %{
        schema_struct: schema_struct,
        jobs: %{
          delete_object_and_upload: delete_object_and_upload_job
        }
      }}
    end
  end

  def schedule_delete_object_and_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      schedule_delete_object_and_upload(bucket, query, schema_struct, update_params, opts)
    end
  end

  @doc """
  ...
  """
  def complete_upload(
    bucket,
    destination_object,
    query,
    %_{} = schema_struct,
    update_params,
    opts
  ) do
    if schema_struct.upload_id do
      {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
        schema_struct: schema_struct,
        query: query,
        bucket: bucket
      })}
    else
      case Storage.head_object(bucket, schema_struct.key, opts) do
        {:ok, metadata} ->
          do_complete_upload(
            bucket,
            destination_object,
            query,
            schema_struct,
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
    object_path_params,
    query,
    find_params,
    update_params,
    opts
  ) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      complete_upload(
        bucket,
        object_path_params,
        query,
        schema_struct,
        update_params,
        opts
      )
    end
  end

  defp do_complete_upload(
    bucket,
    destination_object,
    query,
    schema_struct,
    update_params,
    metadata,
    opts
  ) do
    update_params =
      Map.merge(update_params, %{
        state: :available,
        e_tag: metadata.e_tag
      })

    operation =
      fn ->
        with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, process_upload_job} <-
              Scheduler.queue_process_upload(
                bucket,
                destination_object,
                query,
                schema_struct.id,
                opts[:pipeline],
                opts
              ) do
              {:ok, %{
                metadata: metadata,
                schema_struct: schema_struct,
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
  def abort_upload(bucket, query, %_{} = schema_struct, update_params, opts) do
    if schema_struct.upload_id do
      {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
        schema_struct: schema_struct,
        query: query,
        bucket: bucket
      })}
    else
      operation =
        fn ->
          do_abort_upload(bucket, query, schema_struct, update_params, opts)
        end

      DBAction.transaction(operation, opts)
    end
  end

  def abort_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_struct, update_params, opts)
    end
  end

  defp do_abort_upload(bucket, query, schema_struct, update_params, opts) do
    state = opts[:state] || :cancelled

    unless state in [:discarded, :cancelled] do
      raise ArgumentError, "expected state to be one of [:discarded, :cancelled]"
    end

    update_params = Map.put(update_params, :state, state)

    with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
      if Keyword.get(opts, :scheduler_enabled, true) do
        with {:ok, delete_object_and_upload_job} <-
          Scheduler.queue_delete_object_and_upload(
            bucket,
            query,
            schema_struct.id,
            opts
          ) do
          {:ok, %{
            schema_struct: schema_struct,
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
        with {:ok, schema_struct} <- DBAction.create(query, create_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, abort_upload_job} <-
              Scheduler.queue_abort_upload(
                bucket,
                query,
                schema_struct.id,
                opts
              ) do
              {:ok, %{
                presigned_upload: presigned_upload,
                schema_struct: schema_struct,
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
    %_{} = schema_struct,
    next_part_number_marker,
    opts
  ) do
    if is_nil(schema_struct.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_struct: schema_struct
      })}
    else
      with {:ok, parts} <-
        Storage.list_parts(
          bucket,
          schema_struct.key,
          schema_struct.upload_id,
          next_part_number_marker,
          opts
        ) do
        {:ok, %{
          parts: parts,
          schema_struct: schema_struct
        }}
      end
    end
  end

  def find_parts(bucket, query, find_params, next_part_number_marker, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_struct, next_part_number_marker, opts)
    end
  end

  @doc """
  ...
  """
  def presigned_part(bucket, query, %_{} = schema_struct, part_number, opts) do
    if is_nil(schema_struct.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        bucket: bucket,
        query: query,
        schema_struct: schema_struct,
        part_number: part_number
      })}
    else
      with {:ok, presigned_part} <-
          Storage.presigned_part_upload(
            bucket,
            schema_struct.key,
            schema_struct.upload_id,
            part_number,
            opts
          ) do
        {:ok, %{
          presigned_part: presigned_part,
          schema_struct: schema_struct
        }}
      end
    end
  end

  def presigned_part(bucket, query, params, part_number, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, params, opts) do
      presigned_part(bucket, query, schema_struct, part_number, opts)
    end
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
    bucket,
    destination_object,
    query,
    %_{} = schema_struct,
    update_params,
    parts,
    opts
  ) do
    if is_nil(schema_struct.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_struct: schema_struct,
        query: query
      })}
    else
      with {:ok, metadata} <-
        storage_complete_multipart_upload(
          bucket,
          schema_struct,
          parts,
          opts
        ) do
        do_complete_multipart_upload(
          bucket,
          destination_object,
          query,
          schema_struct,
          update_params,
          metadata,
          opts
        )
      end
    end
  end

  def complete_multipart_upload(
    bucket,
    object_path_params,
    query,
    find_params,
    update_params,
    parts,
    opts
  ) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        object_path_params,
        query,
        schema_struct,
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
    schema_struct,
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

        with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, process_upload_job} <-
              Scheduler.queue_process_upload(
                bucket,
                destination_object,
                query,
                schema_struct.id,
                opts[:pipeline],
                opts
              ) do
              {:ok, %{
                metadata: metadata,
                schema_struct: schema_struct,
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
    schema_struct,
    parts,
    opts
  ) do
    case Storage.complete_multipart_upload(
      bucket,
      schema_struct.key,
      schema_struct.upload_id,
      parts,
      opts
    ) do
      {:ok, _} -> Storage.head_object(bucket, schema_struct.key, opts)
      {:error, %{code: :not_found}} -> Storage.head_object(bucket, schema_struct.key, opts)
      {:error, _} = error -> error
    end
  end

  @doc """
  ...
  """
  def abort_multipart_upload(bucket, query, %_{} = schema_struct, update_params, opts) do
    if is_nil(schema_struct.upload_id) do
      {:error, Error.call(:forbidden, "expected a multipart upload", %{
        schema_struct: schema_struct,
        query: query
      })}
    else
      case Storage.abort_multipart_upload(bucket, schema_struct.key, schema_struct.upload_id, opts) do
        {:ok, metadata} ->
          with {:ok, res} <-
            do_abort_multipart_upload(
              bucket,
              query,
              schema_struct,
              update_params,
              opts
            ) do
            {:ok, Map.put(res, :metadata, metadata)}
          end

        {:error, %{code: :not_found}} ->
          do_abort_multipart_upload(
            bucket,
            query,
            schema_struct,
            update_params,
            opts
          )

        {:error, _} = error ->
          error

      end
    end
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_struct, update_params, opts)
    end
  end

  defp do_abort_multipart_upload(
    bucket,
    query,
    schema_struct,
    update_params,
    opts
  ) do
    state = opts[:state] || :cancelled

    unless state in [:discarded, :cancelled] do
      raise ArgumentError, "expected state to be one of [:discarded, :cancelled]"
    end

    update_params = Map.put(update_params, :state, state)

    operation =
      fn ->
        with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, delete_object_and_upload_job} <-
              Scheduler.queue_delete_object_and_upload(
                bucket,
                query,
                schema_struct.id,
                opts
              ) do
              {:ok, %{
                schema_struct: schema_struct,
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
      create_params =
        Map.merge(create_params, %{
          state: :pending,
          upload_id: multipart_upload.upload_id,
          key: destination_object
        })

      operation = fn ->
        with {:ok, schema_struct} <- DBAction.create(query, create_params, opts) do
          if Keyword.get(opts, :scheduler_enabled, true) do
            with {:ok, abort_multipart_upload_job} <-
              Scheduler.queue_abort_multipart_upload(
                bucket,
                query,
                schema_struct.id,
                opts
              ) do
              {:ok, %{
                multipart_upload: multipart_upload,
                schema_struct: schema_struct,
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
