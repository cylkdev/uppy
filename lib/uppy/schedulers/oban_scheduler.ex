defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc """
  ...
  """

  alias Uppy.Schedulers.{
    ObanScheduler,
    ObanScheduler.CommonAction,
    ObanScheduler.Events,
    ObanScheduler.WorkerAPI,
    ObanScheduler.Workers
  }

  @doc """
  ...
  """
  def queue_move_upload(bucket, destination, query, id, pipeline, opts) do
    opts = Keyword.merge(ObanScheduler.Config.scheduler(), opts)

    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.move_upload(),
        bucket: bucket,
        destination: destination,
        id: id,
        pipeline: pipeline
      })

    CommonAction.insert(Workers.UploadTransferWorker, params, opts)
  end

  @doc """
  ...
  """
  def queue_abort_multipart_upload(bucket, query, id, opts) do
    opts = Keyword.merge(ObanScheduler.Config.scheduler(), opts)

    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.abort_multipart_upload(),
        bucket: bucket,
        id: id
      })

    CommonAction.insert(Workers.UploadTimeoutWorker, params, opts)
  end

  @doc """
  ...
  """
  def queue_abort_upload(bucket, query, id, opts) do
    opts = Keyword.merge(ObanScheduler.Config.scheduler(), opts)

    params =
      query
      |> WorkerAPI.query_to_arguments()
      |> Map.merge(%{
        event: Events.abort_upload(),
        bucket: bucket,
        id: id
      })

    CommonAction.insert(Workers.UploadTimeoutWorker, params, opts)
  end
end
