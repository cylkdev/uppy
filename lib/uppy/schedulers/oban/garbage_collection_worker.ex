if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban.GarbageCollectionWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :garbage_collection,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Core
    alias Uppy.Schedulers.Oban.{
      EventName,
      ObanUtil
    }

    @event_garbage_collect_object EventName.garbage_collect_object()

    def perform(%Oban.Job{
      args: %{
        "event" => @event_garbage_collect_object,
        "bucket" => bucket,
        "key" => key,
        "query" => query
      }
    }) do
      Core.garbage_collect_object(bucket, ObanUtil.decode_binary_to_term(query), key)
    end

    def queue_garbage_collect_object(
      bucket,
      query,
      key,
      schedule,
      opts
    ) do
      %{
        event: @event_garbage_collect_object,
        bucket: bucket,
        key: key,
        query: ObanUtil.encode_term_to_binary(query)
      }
      |> new()
      |> ObanUtil.insert(schedule, opts)
    end
  end
end
