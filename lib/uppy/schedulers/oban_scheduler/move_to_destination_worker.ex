defmodule Uppy.Schedulers.ObanScheduler.Workers.MoveToDestinationWorker do
  @max_attempts 10

  use Oban.Worker,
    queue: :move_to_destination,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Core,
    Schedulers.ObanScheduler.CommonAction
  }

  @event_move_to_destination "uppy.move_to_destination"

  def perform(%{attempt: @max_attempts, args: args}) do
    CommonAction.insert(__MODULE__, args, CommonAction.random_minutes(), [])
  end

  def perform(%Oban.Job{
        args:
          %{
            "event" => @event_move_to_destination,
            "bucket" => bucket,
            "destination_object" => destination_object,
            "id" => id
          } = args
      }) do
    Core.move_to_destination(
      bucket,
      CommonAction.get_args_query(args),
      %{id: id},
      destination_object,
      []
    )
  end

  def queue_move_to_destination(bucket, query, id, dest_object, schedule_in_or_at, opts) do
    params =
      query
      |> CommonAction.query_to_args()
      |> Map.merge(%{
        event: @event_move_to_destination,
        bucket: bucket,
        destination_object: dest_object,
        id: id
      })

    CommonAction.insert(__MODULE__, params, schedule_in_or_at, opts)
  end
end
