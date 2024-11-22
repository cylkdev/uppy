defmodule Uppy.Schedulers.ObanScheduler.Workers.UploadTransferWorker do
  @max_attempts 10

  @moduledoc """
  Moves existing objects to pre-set destinations.
  """
  use Oban.Worker,
    queue: :upload_transfer,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Schedulers.ObanScheduler,
    Schedulers.ObanScheduler.Action,
    Schedulers.ObanScheduler.Events,
    Schedulers.ObanScheduler.WorkerAPI
  }

  @event_move_upload Events.move_upload()

  @doc """
  ...

  ### Eventss

    * `#{@event_move_upload}`
  """
  @spec perform(Oban.Job.t()) :: {:ok, term()} | {:error, term()}
  def perform(%Oban.Job{
        attempt: @max_attempts,
        args: args
      }) do
    Action.insert(
      ObanScheduler.Config.scheduler()[:upload_transfer_worker],
      args,
      ObanScheduler.Config.scheduler()[:worker_options]
    )
  end

  def perform(%Oban.Job{
        args:
          %{
            "event" => @event_move_upload,
            "bucket" => bucket,
            "destination" => destination_object,
            "pipeline" => pipeline,
            "id" => id
          } = args
      }) do
    WorkerAPI.move_upload(
      bucket,
      destination_object,
      WorkerAPI.query_from_arguments(args),
      String.to_integer(id),
      WorkerAPI.string_to_module(pipeline),
      ObanScheduler.Config.scheduler()[:worker_options]
    )
  end
end
