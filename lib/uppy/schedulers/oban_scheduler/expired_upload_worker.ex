if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.ExpiredUploadWorker do
    @moduledoc false
      alias Uppy.Schedulers.ObanScheduler
    use Oban.Worker,
      queue: :expired_upload,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler

    @event_abort_multipart_upload ObanScheduler.events().abort_multipart_upload
    @event_abort_upload ObanScheduler.events().abort_upload

    def perform(%Oban.Job{
      args: %{
        "event" => @event_abort_multipart_upload,
        "bucket" => bucket,
        "id" => id,
        "query" => query
      }
    }) do
      ObanScheduler.perform_abort_multipart_upload(
        bucket,
        query,
        id
      )
    end

    def perform(%Oban.Job{
      args: %{
        "event" => @event_abort_upload,
        "bucket" => bucket,
        "query" => query,
        "id" => id
      }
    }) do
      ObanScheduler.perform_abort_upload(
        bucket,
        query,
        id
      )
    end
  end
end
