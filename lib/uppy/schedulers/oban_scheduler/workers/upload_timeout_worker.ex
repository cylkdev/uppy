defmodule Uppy.Schedulers.ObanScheduler.Workers.UploadTimeoutWorker do
  @max_attempts 10

  @moduledoc """
  Aborts non-multipart and multipart uploads that have not
  been completed after a set amount of time.
  """
  use Oban.Worker,
    queue: :upload_timeout,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Schedulers.ObanScheduler,
    Schedulers.ObanScheduler.CommonAction,
    Schedulers.ObanScheduler.Events,
    Schedulers.ObanScheduler.WorkerAPI
  }

  @event_abort_multipart_upload Events.abort_multipart_upload()
  @event_abort_upload Events.abort_upload()

  @doc """
  ...

  Eventss:

    * `#{@event_abort_multipart_upload}`
    * `#{@event_abort_upload}`
  """
  @spec perform(Oban.Job.t()) :: {:ok, term()} | {:error, term()}
  def perform(%Oban.Job{
        attempt: @max_attempts,
        args: args
      }) do
    CommonAction.insert(
      __MODULE__,
      args,
      ObanScheduler.Config.scheduler()
    )
  end

  def perform(%Oban.Job{
        args:
          %{
            "event" => @event_abort_multipart_upload,
            "bucket" => bucket,
            "id" => id
          } = args
      }) do
    WorkerAPI.abort_multipart_upload(
      bucket,
      WorkerAPI.query_from_arguments(args),
      String.to_integer(id),
      ObanScheduler.Config.scheduler()
    )
  end

  def perform(%Oban.Job{
        args:
          %{
            "event" => @event_abort_upload,
            "bucket" => bucket,
            "id" => id
          } = args
      }) do
    WorkerAPI.abort_upload(
      bucket,
      WorkerAPI.query_from_arguments(args),
      String.to_integer(id),
      ObanScheduler.Config.scheduler()
    )
  end
end
