if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Uploader.Engines.ObanEngine.ExpiredUploadWorker do
    @max_attempts 4

    use Oban.Worker,
      queue: :expired_upload,
      max_attempts: @max_attempts,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Uploader.Engines.ObanEngine.WorkerAPI

    @event WorkerAPI.events().abort_expired_upload

    def perform(%{args: %{"event" => @event}} = job) do
      WorkerAPI.perform(__MODULE__, job, max_attempts: @max_attempts)
    end

    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      WorkerAPI.enqueue_abort_expired_upload(__MODULE__, bucket, query, id, opts)
    end
  end
end
