if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban.GarbageCollectorWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :garbage_collection,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.Oban.{Arguments, Global}
    alias Uppy.{Core, Utils}

    @event_prefix "uppy.garbage_collector_worker"
    @event_delete_object_if_upload_not_found "#{@event_prefix}.delete_object_if_upload_not_found"

    def perform(%Oban.Job{
          args: %{
            "event" => @event_delete_object_if_upload_not_found,
            "bucket" => bucket,
            "schema" => schema,
            "source" => source,
            "key" => key
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.delete_object_if_upload_not_found(bucket, {schema, source}, key)
    end

    def perform(%Oban.Job{
          args: %{
            "event" => @event_delete_object_if_upload_not_found,
            "bucket" => bucket,
            "schema" => schema,
            "key" => key
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.delete_object_if_upload_not_found(bucket, schema, key)
    end

    def queue_delete_object_if_upload_not_found(
          bucket,
          schema,
          key,
          schedule_at_or_schedule_in,
          options
        ) do
      options = ensure_schedule_opt(options, schedule_at_or_schedule_in)

      changeset =
        schema
        |> Arguments.convert_schema_to_arguments()
        |> Map.merge(%{
          event: @event_delete_object_if_upload_not_found,
          bucket: bucket,
          key: key
        })
        |> new()

      Global.insert(changeset, options)
    end

    defp ensure_schedule_opt(options, %DateTime{} = schedule_at) do
      Keyword.put(options, :schedule_at, schedule_at)
    end

    defp ensure_schedule_opt(options, schedule_in) when is_integer(schedule_in) do
      Keyword.put(options, :schedule_in, schedule_in)
    end
  end
end
