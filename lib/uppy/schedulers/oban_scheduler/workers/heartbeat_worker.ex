defmodule Uppy.Schedulers.ObanScheduler.Workers.HeartbeatWorker do
  @max_attempts 10

  @moduledoc """
  Aborts non-multipart and multipart uploads that have not
  been completed after a set amount of time.
  """
  use Oban.Worker,
    queue: :heartbeat,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Schedulers.ObanScheduler.Action,
    Schedulers.ObanScheduler.EventName,
    Schedulers.ObanScheduler.WorkerAPI
  }

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @event_abort_multipart_upload EventName.abort_multipart_upload()
  @event_abort_upload EventName.abort_upload()

  @doc """
  ...

  EventNames:

    * `#{@event_abort_multipart_upload}`
    * `#{@event_abort_upload}`
  """
  @spec perform(Oban.Job.t()) :: {:ok, term()} | {:error, term()}
  def perform(%Oban.Job{
        attempt: @max_attempts,
        args: args
      }) do
    Action.insert(__MODULE__, args, @config[:options] || [])
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
      @config[:abort_multipart_upload][:options] || []
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
      @config[:abort_upload][:options] || []
    )
  end
end
