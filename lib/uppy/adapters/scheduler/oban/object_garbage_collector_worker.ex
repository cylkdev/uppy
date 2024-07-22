if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :garbage_collection,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

      alias Uppy.{Core, Config, Utils}

    @event_prefix "uppy.garbage_collector"
    @event_garbage_collect_object "#{@event_prefix}.garbage_collect_object"

    def perform(%Oban.Job{
      args: %{
        "event" => @event_garbage_collect_object,
        "bucket" => bucket,
        "schema" => schema,
        "key" => key
      }
    }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.garbage_collect_object(bucket, schema, key)
    end

    def queue_garbage_collect_object(bucket, schema, key, schedule_at_or_schedule_in, options) do
      options = ensure_schedule_opt(options, schedule_at_or_schedule_in)

      changeset = new(%{
        event: @event_garbage_collect_object,
        bucket: bucket,
        schema: Utils.module_to_string(schema),
        key: key
      })

      Oban.insert(oban_name(), changeset, options)
    end

    defp ensure_schedule_opt(options, %DateTime{} = schedule_at) do
      Keyword.put(options, :schedule_at, schedule_at)
    end

    defp ensure_schedule_opt(options, schedule_in) when is_integer(schedule_in) do
      Keyword.put(options, :schedule_in, schedule_in)
    end

    defp oban_name do
      Config.oban()[:name] || Uppy.Oban
    end
  end
end
