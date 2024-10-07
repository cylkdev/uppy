if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Schedulers.Oban.PostProcessingWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :post_processing,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.{Core, Utils}
    alias Uppy.Schedulers.Oban.{
      EventName,
      ObanUtil
    }

    @event_process_upload EventName.process_upload()

    def perform(%Oban.Job{
      args: %{
        "event" => @event_process_upload,
        "bucket" => bucket,
        "pipeline" => pipeline,
        "resource" => resource,
        "query" => query,
        "id" => id
      }
    }) do
      pipeline
      |> Utils.string_to_existing_module!()
      |> Core.process_upload(
        bucket,
        resource,
        ObanUtil.decode_binary_to_term(query),
        %{id: id}
      )
    end

    def queue_process_upload(
      pipeline,
      bucket,
      resource,
      query,
      id,
      schedule,
      opts
    ) do
      %{
        event: @event_process_upload,
        pipeline: Utils.module_to_string(pipeline),
        bucket: bucket,
        resource: resource,
        query: ObanUtil.encode_term_to_binary(query),
        id: id
      }
      |> new()
      |> ObanUtil.insert(schedule, opts)
    end
  end
end
