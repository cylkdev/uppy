if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.Oban.AbortExpiredMultipartUploadWorker do
    @max_attempts 4

    use Oban.Worker,
      queue: :abort_expired_multipart_upload,
      max_attempts: @max_attempts,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.Oban.WorkerAPI

    @event WorkerAPI.events().abort_expired_multipart_upload

    def perform(%{args: %{"event" => @event}} = job) do
      WorkerAPI.perform(__MODULE__, job, max_attempts: @max_attempts)
    end

    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      WorkerAPI.enqueue_abort_expired_multipart_upload(__MODULE__, bucket, query, id, opts)
    end
  end
end
