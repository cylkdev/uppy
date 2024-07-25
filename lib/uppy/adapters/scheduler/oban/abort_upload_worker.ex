if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban.AbortUploadWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :abort_upload,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Adapters.Scheduler.Oban.{Arguments, Global}
    alias Uppy.{Core, Utils}

    @event_prefix "uppy.abort_upload_worker"
    @event_abort_upload "#{@event_prefix}.abort_upload"
    @event_abort_multipart_upload "#{@event_prefix}.abort_multipart_upload"

    def perform(%Oban.Job{
          args: %{
            "event" => @event_abort_multipart_upload,
            "bucket" => bucket,
            "schema" => schema,
            "source" => source,
            "id" => id
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.abort_multipart_upload(bucket, {schema, source}, %{id: id})
    end

    def perform(%Oban.Job{
          args: %{
            "event" => @event_abort_multipart_upload,
            "bucket" => bucket,
            "schema" => schema,
            "id" => id
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.abort_multipart_upload(bucket, schema, %{id: id})
    end

    def perform(%Oban.Job{
          args: %{
            "event" => @event_abort_upload,
            "bucket" => bucket,
            "schema" => schema,
            "source" => source,
            "id" => id
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.abort_upload(bucket, {schema, source}, %{id: id})
    end

    def perform(%Oban.Job{
          args: %{
            "event" => @event_abort_upload,
            "bucket" => bucket,
            "schema" => schema,
            "id" => id
          }
        }) do
      schema = Utils.string_to_existing_module!(schema)

      Core.abort_upload(bucket, schema, %{id: id})
    end

    def queue_abort_multipart_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      options = ensure_schedule_opt(options, schedule_at_or_schedule_in)

      changeset =
        schema
        |> Arguments.convert_schema_to_arguments()
        |> Map.merge(%{
          event: @event_abort_multipart_upload,
          bucket: bucket,
          id: id
        })
        |> new()

      Global.insert(changeset, options)
    end

    def queue_abort_upload(bucket, schema, id, schedule_at_or_schedule_in, options) do
      options = ensure_schedule_opt(options, schedule_at_or_schedule_in)

      changeset =
        schema
        |> Arguments.convert_schema_to_arguments()
        |> Map.merge(%{
          event: @event_abort_upload,
          bucket: bucket,
          id: id
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
