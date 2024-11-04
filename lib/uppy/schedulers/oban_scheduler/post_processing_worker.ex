if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.PostProcessingWorker do
    @moduledoc """
    ...
    """

    use Oban.Worker,
      queue: :post_processing,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler

    @event_move_upload ObanScheduler.events().move_upload

    def perform(%Oban.Job{
      args: %{
        "event" => @event_move_upload,
        "bucket" => bucket,
        "destination_object" => destination_object,
        "query" => encoded_query,
        "id" => id,
        "pipeline" => pipeline
      }
    }) do
      ObanScheduler.perform_move_upload(
        bucket,
        destination_object,
        encoded_query,
        id,
        pipeline
      )
    end
  end
end
