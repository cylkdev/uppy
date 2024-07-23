defmodule Uppy.Schedulers do
  def queue_delete_object_if_upload_not_found(
        scheduler_adapter,
        bucket,
        schema,
        key,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> scheduler_adapter.queue_delete_object_if_upload_not_found(
      schema,
      key,
      schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  def queue_abort_multipart_upload(
        scheduler_adapter,
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> scheduler_adapter.queue_abort_multipart_upload(
      schema,
      id,
      schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  def queue_abort_upload(
        scheduler_adapter,
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> scheduler_adapter.queue_abort_upload(schema, id, schedule_at_or_schedule_in, options)
    |> handle_response()
  end

  def queue_run_pipeline(
        scheduler_adapter,
        pipeline_module,
        bucket,
        resource_name,
        schema,
        id,
        maybe_schedule_at_or_schedule_in,
        options
      ) do
    pipeline_module
    |> scheduler_adapter.queue_run_pipeline(
      bucket,
      resource_name,
      schema,
      id,
      maybe_schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, _} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, term()}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end
end

# defmodule Uppy.Schedulers do
#   def queue(adapter, action, params, maybe_seconds_or_date_time, options) do
#     adapter.queue(action, params, maybe_seconds_or_date_time, options)
#   end
# end
