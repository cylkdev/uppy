defmodule Uppy.Adapters.Scheduler.Oban do
  alias Uppy.Adapter

  alias Uppy.Adapters.Scheduler.Oban.{
    GarbageCollectorWorker,
    ExpiredUploadAborterWorker,
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
  def enqueue(:abort_upload, params, %DateTime{} = date_time, options) do
    ExpiredUploadAborterWorker.schedule_abort_upload(
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
    ExpiredUploadAborterWorker.schedule_abort_upload(
      params,
      seconds,
      options
    )
  end

  @spec enqueue(
          :delete_aborted_upload_object,
          params :: map(),
          date_time :: DateTime.t(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:delete_aborted_upload_object, params, %DateTime{} = date_time, options) do
    GarbageCollectorWorker.schedule_delete_aborted_upload_object(
      params,
      date_time,
      options
    )
  end

  @spec enqueue(
          :delete_aborted_upload_object,
          params :: map(),
          seconds :: non_neg_integer(),
          options :: Keyword.t()
        ) :: term
  def enqueue(:delete_aborted_upload_object, params, seconds, options)
      when is_integer(seconds) do
    GarbageCollectorWorker.schedule_delete_aborted_upload_object(
      params,
      seconds,
      options
    )
  end

  @spec enqueue(
          :move_upload_to_permanent_storage,
          params :: map(),
          nil,
          options :: Keyword.t()
        ) :: term
  def enqueue(:move_upload_to_permanent_storage, params, nil, options) do
    PostProcessorWorker.queue_move_upload_to_permanent_storage(
      params,
      options
    )
  end
end
