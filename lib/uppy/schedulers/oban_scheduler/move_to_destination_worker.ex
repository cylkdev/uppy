if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.MoveToDestinationWorker do
    @max_attempts 4

    use Oban.Worker,
      queue: :move_to_destination,
      max_attempts: @max_attempts,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler.WorkerAPI

    @event WorkerAPI.events().move_to_destination

    def perform(%{args: %{"event" => @event}} = job) do
      WorkerAPI.perform(job, max_attempts: @max_attempts)
    end

    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      WorkerAPI.enqueue_move_to_destination(bucket, query, id, dest_object, opts)
    end
  end
end
