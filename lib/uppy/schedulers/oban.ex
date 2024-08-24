if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban do
    alias Uppy.Schedulers.Oban.{
      GarbageCollectorWorker,
      PostProcessingWorker,
      AbortUploadWorker
    }

    def queue_delete_object_if_upload_not_found(
          bucket,
          schema,
          key,
          schedule_at_or_schedule_in,
          options
        ) do
      GarbageCollectorWorker.queue_delete_object_if_upload_not_found(
        bucket,
        schema,
        key,
        schedule_at_or_schedule_in,
        options
      )
    end

    @doc """
    ...
    """
    def queue_abort_multipart_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      AbortUploadWorker.queue_abort_multipart_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      )
    end

    @doc """
    ...
    """
    def queue_abort_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      AbortUploadWorker.queue_abort_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      )
    end

    @doc """
    ...
    """
    def queue_process_upload(
          pipeline_module,
          bucket,
          resource,
          schema,
          id,
          nil_or_schedule_at_or_schedule_in,
          options
        ) do
      PostProcessingWorker.queue_process_upload(
        pipeline_module,
        bucket,
        resource,
        schema,
        id,
        nil_or_schedule_at_or_schedule_in,
        options
      )
    end
  end
end
