if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban do
    alias Uppy.Utils

    alias Uppy.Adapters.Scheduler.Oban.{
      GarbageCollectorWorker,
      PostProcessingWorker,
      AbortUploadWorker
    }

    def convert_schema_to_job_arguments({schema, source}) do
      %{
        schema: Utils.module_to_string(schema),
        source: source
      }
    end

    def convert_schema_to_job_arguments(schema) do
      %{
        schema: Utils.module_to_string(schema)
      }
    end

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
    def queue_run_pipeline(
          pipeline_module,
          bucket,
          resource_name,
          schema,
          id,
          nil_or_schedule_at_or_schedule_in,
          options
        ) do
      PostProcessingWorker.queue_run_pipeline(
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
