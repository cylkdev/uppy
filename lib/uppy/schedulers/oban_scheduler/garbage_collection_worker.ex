if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.GarbageCollectionWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :garbage_collection,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler

    @event_garbage_collect_upload ObanScheduler.events().garbage_collect_upload

    def perform(%Oban.Job{
      args: %{
        "event" => @event_garbage_collect_upload,
        "bucket" => bucket,
        "id" => id,
        "query" => query
      }
    }) do
      ObanScheduler.perform_garbage_collect_upload(
        bucket,
        id,
        query
      )
    end
  end
end
