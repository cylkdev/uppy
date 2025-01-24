defmodule Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredUploadWorker do
  @max_attempts 10

  @moduledoc """
  Aborts non-multipart and multipart uploads that have not
  been completed after a set amount of time.
  """
  use Oban.Worker,
    queue: :abort_expired_upload,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Core,
    Schedulers.ObanScheduler.CommonAction
  }

  @event_abort_expired_upload "uppy.abort_expired_upload"

  def event_abort_expired_upload, do: @event_abort_expired_upload

  def perform(%{attempt: @max_attempts, args: args}) do
    CommonAction.insert(__MODULE__, args, CommonAction.random_minutes(), [])
  end

  def perform(%{
        args:
          %{
            "event" => @event_abort_expired_upload,
            "bucket" => bucket,
            "id" => id
          } = args
      }) do
    with {:error, %{code: :not_found}} <-
           Core.abort_upload(
             bucket,
             CommonAction.get_args_query(args),
             %{id: id},
             %{state: :expired},
             []
           ) do
      {:ok, "skipping - object or record not found"}
    end
  end

  def queue_abort_expired_upload(bucket, query, id, schedule_in_or_at, opts) do
    params =
      query
      |> CommonAction.query_to_args()
      |> Map.merge(%{
        event: @event_abort_expired_upload,
        bucket: bucket,
        id: id
      })

    CommonAction.insert(__MODULE__, params, schedule_in_or_at, opts)
  end
end
