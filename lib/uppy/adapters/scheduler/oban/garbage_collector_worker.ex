if Uppy.Utils.application_loaded?(:oban) do
  defmodule Uppy.Adapters.Scheduler.Oban.GarbageCollectorWorker do
    @moduledoc false
    use Oban.Worker,
      queue: :garbage_collection,
      unique: [
        period: 300,
        states: [:available, :scheduled, :executing]
      ]

    alias Uppy.{
      Adapters.Scheduler.Oban.AdapterConfig,
      Uploader,
      Utils
    }

    @type params :: Uppy.params()
    @type max_age_in_seconds :: Uppy.max_age_in_seconds()
    @type options :: Uppy.options()

    @type oban_insert_response :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | term()}

    @event_prefix "uppy.garbage_collector"
    @event_garbage_collect_object "#{@event_prefix}.garbage_collect_object"

    def perform(%Oban.Job{
          args: %{
            "event" => @event_garbage_collect_object,
            "uploader" => uploader,
            "key" => key
          }
        }) do
      uploader
      |> Utils.to_existing_module!()
      |> Uploader.garbage_collect_object(key)
    end

    def schedule_garbage_collect_object(uploader, key, date_time_or_seconds, options) do
      Oban.insert(
        AdapterConfig.oban_name(),
        new(%{
          event: @event_garbage_collect_object,
          uploader: Utils.module_to_string(uploader),
          key: key
        }),
        schedule_opt(options, date_time_or_seconds)
      )
    end

    defp schedule_opt(options, %DateTime{} = date_time) do
      Keyword.put(options, :schedule_at, date_time)
    end

    defp schedule_opt(options, seconds) when is_integer(seconds) do
      Keyword.put(options, :schedule_in, seconds)
    end
  end
end
