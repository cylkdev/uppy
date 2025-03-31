if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.Workers.MoveToDestinationWorker do
    use Oban.Worker,
      queue: :move_to_destination,
      max_attempts: 4,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.ObanScheduler.WorkerAPI

    def perform(job) do
      WorkerAPI.perform(job)
    end
  end
end
