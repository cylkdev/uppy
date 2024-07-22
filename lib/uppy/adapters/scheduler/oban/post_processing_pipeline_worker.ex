if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban.PostProcessingPipelineWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :post_processing,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.{Core, Config, Utils}

    @event_prefix "uppy"
    @event_run_pipeline "#{@event_prefix}.run_pipeline"

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

    def queue_run_pipeline(pipeline_module, bucket, resource_name, schema, id, nil_or_schedule_at_or_schedule_in, options) do
      options = ensure_schedule_opt(options, nil_or_schedule_at_or_schedule_in)

      changeset = new(%{
        event: @event_run_pipeline,
        pipeline: Utils.module_to_string(pipeline_module),
        bucket: bucket,
        resource_name: resource_name,
        schema: Utils.module_to_string(schema),
        id: id
      })

      Oban.insert(oban_name(), changeset, options)
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

    defp oban_name do
      Config.oban()[:name] || Uppy.Oban
    end
  end
end
