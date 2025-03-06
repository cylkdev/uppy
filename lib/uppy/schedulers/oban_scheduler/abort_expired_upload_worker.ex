if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.AbortExpiredUploadWorker do
    @max_attempts 4

    use Oban.Worker,
      queue: :abort_expired_upload,
      max_attempts: @max_attempts,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler.WorkerAPI

    @event WorkerAPI.events().abort_expired_upload

    def perform(%{args: %{"event" => @event}} = job) do
      WorkerAPI.perform(job, max_attempts: @max_attempts)
    end

    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      WorkerAPI.enqueue_abort_expired_upload(bucket, query, id, opts)
    end
  end
end
