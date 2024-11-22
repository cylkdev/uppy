defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc """
  ...
  """

  alias Uppy.{
    Schedulers.ObanScheduler,
    Schedulers.ObanScheduler.Action,
    Schedulers.ObanScheduler.Events,
    Schedulers.ObanScheduler.WorkerAPI
  }

  @doc """
  ...
  """
  def queue_move_upload(bucket, destination, query, id, pipeline, opts) do
    Action.insert(
      ObanScheduler.Config.scheduler()[:upload_transfer_worker],
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.move_upload(),
        bucket: bucket,
        destination: destination,
        id: id,
        pipeline: pipeline
      }),
      opts
    )
  end

  @doc """
  ...
  """
  def queue_abort_multipart_upload(bucket, query, id, opts) do
    Action.insert(
      ObanScheduler.Config.scheduler()[:upload_timeout_worker],
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.abort_multipart_upload(),
        bucket: bucket,
        id: id
      }),
      opts
    )
  end

  @doc """
  ...
  """
  def queue_abort_upload(bucket, query, id, opts) do
    Action.insert(
      ObanScheduler.Config.scheduler()[:upload_timeout_worker],
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.abort_upload(),
        bucket: bucket,
        id: id
      }),
      opts
    )
  end
end
