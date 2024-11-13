defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc """
  ...
  """

  alias Uppy.{
    Schedulers.ObanScheduler.Action,
    Schedulers.ObanScheduler.EventName,
    Schedulers.ObanScheduler.WorkerAPI,
    Schedulers.ObanScheduler.Workers.HeartbeatWorker,
    Schedulers.ObanScheduler.Workers.PostProcessingWorker
  }

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @heartbeat_worker @config[:heartbeat_worker] || HeartbeatWorker
  @post_processing_worker @config[:post_processing_worker] || PostProcessingWorker

  @event_abort_multipart_upload EventName.abort_multipart_upload()
  @event_abort_upload EventName.abort_upload()
  @event_move_upload EventName.move_upload()

  @doc """
  ...
  """
  def queue_move_upload(bucket, destination, query, id, pipeline, opts) do
    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: @event_move_upload,
        bucket: bucket,
        destination: destination,
        id: id,
        pipeline: pipeline
      })

    Action.insert(@post_processing_worker, params, opts)
  end

  @doc """
  ...
  """
  def queue_abort_multipart_upload(bucket, query, id, opts) do
    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: @event_abort_multipart_upload,
        bucket: bucket,
        id: id
      })

    Action.insert(@heartbeat_worker, params, opts)
  end

  @doc """
  ...
  """
  def queue_abort_upload(bucket, query, id, opts) do
    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: @event_abort_upload,
        bucket: bucket,
        id: id
      })

    Action.insert(@heartbeat_worker, params, opts)
  end
end
