defmodule Uppy.Adapters.Scheduler.Oban do
  alias Uppy.Adapter

  alias Uppy.Adapters.Scheduler.Oban.{
    GarbageCollectorWorker,
    UploadAborterWorker,
    PostProcessorWorker
  }

  @behaviour Adapter.Scheduler

  @impl true
  @doc """
  ...
  """
  def enqueue(:abort_multipart_upload, params, %DateTime{} = date_time, options) do
    UploadAborterWorker.schedule_abort_multipart_upload(
      params.uploader,
      params.id,
      date_time,
      options
    )
  end

  def enqueue(:abort_multipart_upload, params, seconds, options) do
    UploadAborterWorker.schedule_abort_multipart_upload(
      params.uploader,
      params.id,
      seconds,
      options
    )
  end

  def enqueue(:abort_upload, params, %DateTime{} = date_time, options) do
    UploadAborterWorker.schedule_abort_upload(
      params.uploader,
      params.id,
      date_time,
      options
    )
  end

  def enqueue(:abort_upload, params, seconds, options) when is_integer(seconds) do
    UploadAborterWorker.schedule_abort_upload(
      params.uploader,
      params.id,
      seconds,
      options
    )
  end

  def enqueue(:garbage_collect_object, params, %DateTime{} = date_time, options) do
    GarbageCollectorWorker.schedule_garbage_collect_object(
      params.uploader,
      params.key,
      date_time,
      options
    )
  end

  def enqueue(:garbage_collect_object, params, seconds, options) when is_integer(seconds) do
    GarbageCollectorWorker.schedule_garbage_collect_object(
      params.uploader,
      params.key,
      seconds,
      options
    )
  end

  def enqueue(:run_pipeline, params, _term, options) do
    PostProcessorWorker.queue_run_pipeline(
      params.uploader,
      params.id,
      options
    )
  end
end
