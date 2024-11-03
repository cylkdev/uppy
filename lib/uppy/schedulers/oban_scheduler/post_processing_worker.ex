if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.PostProcessingWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :post_processing,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler

    @event_process_upload ObanScheduler.events().process_upload

    def perform(%Oban.Job{
      args: %{
        "event" => @event_process_upload,
        "bucket" => bucket,
        "destination_object" => destination_object,
        "query" => encoded_query,
        "id" => id,
        "pipeline" => pipeline
      }
    }) do
      ObanScheduler.perform_process_upload(
        bucket,
        destination_object,
        encoded_query,
        id,
        pipeline
      )
    end
  end
end
