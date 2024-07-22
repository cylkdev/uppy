if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban do

    alias Uppy.Adapters.Scheduler.Oban.{
      GarbageCollectorWorker,
      PostProcessingPipelineWorker,
      AbortUploadWorker
    }

    def queue_garbage_collect_object(bucket, schema, key, schedule_at_or_schedule_in, options) do
      GarbageCollectorWorker.queue_garbage_collect_object(bucket, schema, key, schedule_at_or_schedule_in, options)
    end

    @doc """
    ...
    """
    def queue_abort_multipart_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      AbortUploadWorker.queue_abort_multipart_upload(bucket, schema, id, schedule_at_or_schedule_in, options)
    end

    @doc """
    ...
    """
    def queue_abort_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      AbortUploadWorker.queue_abort_upload(bucket, schema, id, schedule_at_or_schedule_in, options)
    end

    @doc """
    ...
    """
    def queue_run_pipeline(pipeline_module, bucket, resource_name, schema, id, nil_or_schedule_at_or_schedule_in, options) do
      PostProcessingPipelineWorker.queue_run_pipeline(
        pipeline_module,
        bucket,
        resource_name,
        schema,
        id,
        nil_or_schedule_at_or_schedule_in,
        options
      )
    end
  end
end
