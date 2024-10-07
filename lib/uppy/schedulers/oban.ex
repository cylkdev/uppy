if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban do
    @moduledoc """
    ...
    """

    alias Uppy.Schedulers.Oban.{
      AbortUploadWorker,
      GarbageCollectionWorker,
      PostProcessingWorker
    }

    @behaviour Uppy.Scheduler

    @impl Uppy.Scheduler
    defdelegate queue_garbage_collect_object(
      bucket,
      query,
      key,
      schedule,
      opts
    ), to: GarbageCollectionWorker

    @impl Uppy.Scheduler
    defdelegate queue_abort_multipart_upload(
      bucket,
      query,
      id,
      schedule,
      opts
    ), to: AbortUploadWorker

    @impl Uppy.Scheduler
    defdelegate queue_abort_upload(
      bucket,
      query,
      id,
      schedule,
      opts
    ), to: AbortUploadWorker

    @impl Uppy.Scheduler
    defdelegate queue_process_upload(
      pipeline_module,
      bucket,
      resource,
      query,
      id,
      schedule,
      opts
    ), to: PostProcessingWorker
  end
end
