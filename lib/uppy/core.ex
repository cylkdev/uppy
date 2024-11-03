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
    ObjectPath,
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
        _ -> Uppy.Core.PostProcessingPipeline.phases(opts)
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
      context: %{
        destination_object: destination_object
      },
      bucket: bucket,
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
  def garbage_collect_upload(bucket, query, %_{} = schema_struct, opts) do
    if schema_struct.status not in [:discarded, :cancelled] do
      {:error, Error.call(:forbidden, "expected a status of discarded or cancelled", %{
        bucket: bucket,
        query: query,
        schema_struct: schema_struct
      })}
    else
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
    end
  end

  def garbage_collect_upload(bucket, query, find_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      garbage_collect_upload(bucket, query, schema_struct, opts)
    end
  end

  ## Non-Multipart API

  @doc """
  ...
  """
  def delete_upload(bucket, query, %_{} = schema_struct, opts) do
    update_params = %{status: :cancelled}

    with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
      if Keyword.get(opts, :scheduler_enabled, true) do
        with {:ok, garbage_collect_upload_job} <-
          Scheduler.queue_garbage_collect_upload(
            bucket,
            query,
            schema_struct.id,
            opts
          ) do
          {:ok, %{
            schema_struct: schema_struct,
            jobs: %{
              garbage_collect_upload: garbage_collect_upload_job
            }
          }}
        end
      else
        with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts),
          {:ok, res} <- garbage_collect_upload(bucket, query, schema_struct, opts) do
          {:ok, %{schema_struct: res.schema_struct}}
        end
      end
    end
  end

  def delete_upload(bucket, query, params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, params, opts) do
      delete_upload(bucket, query, schema_struct, opts)
    end
  end

  @doc """
  ...
  """
  def complete_upload(
    bucket,
    object_path_params,
    query,
    %_{} = schema_struct,
    update_params,
    opts
  ) do
    destination_object =
      ObjectPath.build_permanent_object_path(
        object_path_params.id,
        object_path_params.partition_name,
        object_path_params.basename,
        opts
      )

    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
      if schema_struct.upload_id do
        {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
          schema_struct: schema_struct,
          query: query,
          bucket: bucket
        })}
      else
        case Storage.head_object(bucket, schema_struct.key, opts) do
          {:ok, metadata} ->
            update_params =
              Map.merge(update_params, %{
                e_tag: metadata.e_tag,
                status: :available
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

          {:error, _} = error ->
            error

        end
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

  @doc """
  ...
  """
  def abort_upload(bucket, query, %_{} = schema_struct, update_params, opts) do
    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
      if schema_struct.upload_id do
        {:error, Error.call(:forbidden, "expected a non-multipart upload", %{
          schema_struct: schema_struct,
          query: query,
          bucket: bucket
        })}
      else
        operation =
          fn ->
            update_params = Map.put(update_params, :status, opts[:status] || :cancelled)

            with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
              if Keyword.get(opts, :scheduler_enabled, true) do
                with {:ok, garbage_collect_upload_job} <-
                  Scheduler.queue_garbage_collect_upload(
                    bucket,
                    query,
                    schema_struct.id,
                    opts
                  ) do
                  {:ok, %{
                    schema_struct: schema_struct,
                    jobs: %{
                      garbage_collect_upload: garbage_collect_upload_job
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

  def abort_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_struct, update_params, opts)
    end
  end

  @doc """
  ...
  """
  def start_upload(bucket, object_path_params, query, create_params, opts) do
    key =
      ObjectPath.build_temporary_object_path(
        object_path_params.id,
        object_path_params.partition_name,
        object_path_params.basename,
        opts
      )

    create_params =
      create_params
      |> Map.put(:status, :pending)
      |> Map.put(:key, key)

    with {:ok, presigned_upload} <- Storage.presigned_upload(bucket, key, opts) do
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
                key: key,
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
    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
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
    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
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
    object_path_params,
    query,
    %_{} = schema_struct,
    update_params,
    parts,
    opts
  ) do
    destination_object =
      ObjectPath.build_permanent_object_path(
        object_path_params.id,
        object_path_params.partition_name,
        object_path_params.basename,
        opts
      )

    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
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

          update_params =
            Map.merge(update_params, %{
              e_tag: metadata.e_tag,
              status: :available
            })

          operation = fn ->
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
    with {:ok, _} <- ObjectPath.validate_temporary_object_path(schema_struct.key, opts) do
      if is_nil(schema_struct.upload_id) do
        {:error, Error.call(:forbidden, "expected a multipart upload", %{
          schema_struct: schema_struct,
          query: query
        })}
      else
        with {:ok, metadata} <-
          storage_abort_multipart_upload(
            bucket,
            schema_struct.key,
            schema_struct.upload_id,
            opts
          ) do

          maybe_metadata = if is_nil(metadata), do: %{}, else: %{metadata: metadata}

          update_params = Map.put(update_params, :status, opts[:status] || :cancelled)

          operation = fn ->
            with {:ok, schema_struct} <- DBAction.update(query, schema_struct, update_params, opts) do
              if Keyword.get(opts, :scheduler_enabled, true) do
                with {:ok, garbage_collect_upload_job} <-
                  Scheduler.queue_garbage_collect_upload(
                    bucket,
                    query,
                    schema_struct.id,
                    opts
                  ) do
                  {:ok, Map.merge(maybe_metadata, %{
                    schema_struct: schema_struct,
                    jobs: %{
                      garbage_collect_upload: garbage_collect_upload_job
                    }
                  })}
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
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    with {:ok, schema_struct} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_struct, update_params, opts)
    end
  end

  defp storage_abort_multipart_upload(bucket, key, upload_id, opts) do
    case Storage.abort_multipart_upload(bucket, key, upload_id, opts) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, %{code: :not_found}} -> {:ok, nil}
      {:error, _} = error -> error
    end
  end

  @doc """
  ...
  """
  def start_multipart_upload(bucket, object_path_params, query, create_params, opts) do
    key =
      ObjectPath.build_temporary_object_path(
        object_path_params.id,
        object_path_params.partition_name,
        object_path_params.basename,
        opts
      )

    with {:ok, multipart_upload} <- Storage.initiate_multipart_upload(bucket, key, opts) do
      create_params =
        create_params
        |> Map.put(:status, :pending)
        |> Map.merge(%{
          upload_id: multipart_upload.upload_id,
          key: key
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
                key: key,
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
