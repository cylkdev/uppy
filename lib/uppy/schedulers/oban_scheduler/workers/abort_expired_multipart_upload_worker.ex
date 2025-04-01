if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredMultipartUploadWorker do
    use Oban.Worker,
      queue: :abort_expired_multipart_upload,
      max_attempts: 4,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler.WorkerAPI

    def perform(job) do
      WorkerAPI.perform(job, [])
    end
  end
end
