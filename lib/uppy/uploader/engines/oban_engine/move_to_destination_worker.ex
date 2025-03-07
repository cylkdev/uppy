if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Uploader.Engines.ObanEngine.MoveToDestinationWorker do
    @max_attempts 4

    use Oban.Worker,
      queue: :move_to_destination,
      max_attempts: @max_attempts,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Uploader.Engines.ObanEngine.WorkerAPI

    @event WorkerAPI.events().move_to_destination

    def perform(%{args: %{"event" => @event}} = job) do
      WorkerAPI.perform(__MODULE__, job, max_attempts: @max_attempts)
    end

    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      WorkerAPI.enqueue_move_to_destination(__MODULE__, bucket, query, id, dest_object, opts)
    end
  end
end
