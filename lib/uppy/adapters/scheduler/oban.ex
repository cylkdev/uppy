defmodule Uppy.Adapters.Scheduler.Oban do
  alias Uppy.Adapter

  alias Uppy.Adapters.Scheduler.Oban.{
    GarbageCollectorWorker,
    UploadAborterWorker,
    PostProcessorWorker
  }

  @behaviour Adapter.Scheduler

  @impl Adapter.Scheduler
  @doc """
  ...
  """
  @spec enqueue(
          :abort_upload,
          params :: map(),
          date_time :: DateTime.t(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:abort_multipart_upload, params, %DateTime{} = date_time, options) do
    UploadAborterWorker.schedule_abort_multipart_upload(
      params,
      date_time,
      options
    )
  end

  @spec enqueue(
          :abort_multipart_upload,
          params :: map(),
          seconds :: non_neg_integer(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:abort_multipart_upload, params, seconds, options) do
    UploadAborterWorker.schedule_abort_multipart_upload(
      params,
      seconds,
      options
    )
  end

  @spec enqueue(
          :abort_upload,
          params :: map(),
          date_time :: DateTime.t(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:abort_upload, params, %DateTime{} = date_time, options) do
    UploadAborterWorker.schedule_abort_upload(
      params,
      date_time,
      options
    )
  end

  @spec enqueue(
          :abort_upload,
          params :: map(),
          seconds :: non_neg_integer(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:abort_upload, params, seconds, options)
      when is_integer(seconds) do
    UploadAborterWorker.schedule_abort_upload(
      params,
      seconds,
      options
    )
  end

  @spec enqueue(
          :garbage_collect_object,
          params :: map(),
          date_time :: DateTime.t(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:garbage_collect_object, params, %DateTime{} = date_time, options) do
    GarbageCollectorWorker.schedule_garbage_collect_object(
      params,
      date_time,
      options
    )
  end

  @spec enqueue(
          :garbage_collect_object,
          params :: map(),
          seconds :: non_neg_integer(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:garbage_collect_object, params, seconds, options)
      when is_integer(seconds) do
    GarbageCollectorWorker.schedule_garbage_collect_object(
      params,
      seconds,
      options
    )
  end

  @spec enqueue(
          :move_temporary_to_permanent_upload,
          params :: map(),
          nil,
          options :: Keyword.t()
        ) :: term
  def enqueue(:move_temporary_to_permanent_upload, params, nil, options) do
    PostProcessorWorker.queue_move_temporary_to_permanent_upload(
      params,
      options
    )
  end
end
