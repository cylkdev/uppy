if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban.PostProcessingWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :post_processing,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.Schedulers.Oban.{Arguments, Global}
    alias Uppy.{Core, Utils}

    @event_prefix "uppy.post_processing_worker"
    @event_run_pipeline "#{@event_prefix}.run_pipeline"

    def perform(%Oban.Job{
          args: %{
            "event" => @event_run_pipeline,
            "pipeline" => pipeline_module,
            "bucket" => bucket,
            "resource_name" => resource_name,
            "schema" => schema,
            "source" => source,
            "id" => id
          }
        }) do
      pipeline_module = Utils.string_to_existing_module!(pipeline_module)
      schema = Utils.string_to_existing_module!(schema)

      Core.run_pipeline(pipeline_module, bucket, resource_name, {schema, source}, %{id: id})
    end

    def perform(%Oban.Job{
          args: %{
            "event" => @event_run_pipeline,
            "pipeline" => pipeline_module,
            "bucket" => bucket,
            "resource_name" => resource_name,
            "schema" => schema,
            "id" => id
          }
        }) do
      pipeline_module = Utils.string_to_existing_module!(pipeline_module)
      schema = Utils.string_to_existing_module!(schema)

      Core.run_pipeline(pipeline_module, bucket, resource_name, schema, %{id: id})
    end

    def queue_run_pipeline(
          pipeline_module,
          bucket,
          resource_name,
          schema,
          id,
          nil_or_schedule_at_or_schedule_in,
          options
        ) do
      options = ensure_schedule_opt(options, nil_or_schedule_at_or_schedule_in)

      changeset =
        schema
        |> Arguments.convert_schema_to_arguments()
        |> Map.merge(%{
          event: @event_run_pipeline,
          pipeline: Utils.module_to_string(pipeline_module),
          bucket: bucket,
          resource_name: resource_name,
          id: id
        })
        |> new()

      Global.insert(changeset, options)
    end

    defp ensure_schedule_opt(options, nil) do
      options
    end

    defp ensure_schedule_opt(options, %DateTime{} = schedule_at) do
      Keyword.put(options, :schedule_at, schedule_at)
    end

    defp ensure_schedule_opt(options, schedule_in) when is_integer(schedule_in) do
      Keyword.put(options, :schedule_in, schedule_in)
    end
  end
end
