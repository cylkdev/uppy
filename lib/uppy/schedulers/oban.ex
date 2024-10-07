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

    defdelegate queue_garbage_collect_object(
      bucket,
      query,
      key,
      schedule,
      opts
    ), to: GarbageCollectionWorker

    defdelegate queue_abort_multipart_upload(
      bucket,
      query,
      id,
      schedule,
      opts
    ), to: AbortUploadWorker

    defdelegate queue_abort_upload(
      bucket,
      query,
      id,
      schedule,
      opts
    ), to: AbortUploadWorker

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
