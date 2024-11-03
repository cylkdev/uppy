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

    @event_delete_object_and_upload ObanScheduler.events().delete_object_and_upload

    def perform(%Oban.Job{
      args: %{
        "event" => @event_delete_object_and_upload,
        "bucket" => bucket,
        "id" => id,
        "query" => query
      }
    }) do
      ObanScheduler.perform_delete_object_and_upload(
        bucket,
        id,
        query
      )
    end
  end
end
