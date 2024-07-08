defmodule Uppy.Adapters.Scheduler.Oban.PostProcessorWorker do
  @moduledoc false
  use Oban.Worker,
    queue: :post_processing,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{Uploader, Utils}

  @type params :: Uppy.params()
  @type max_age_in_seconds :: Uppy.max_age_in_seconds()
  @type options :: Uppy.options()

  @type oban_insert_response :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | term()}

  @event_prefix "uppy.post_processor"
  @event_run_pipeline "#{@event_prefix}.run_pipeline"

  def perform(%Oban.Job{
        args: %{
          "event" => @event_run_pipeline,
          "uploader" => uploader,
          "id" => id
        }
      }) do
    uploader
    |> Utils.to_existing_module!()
    |> Uploader.run_pipeline(%{id: id})
  end

  def queue_run_pipeline(uploader, id, options) do
    Oban.insert(
      oban_name(),
      new(%{
        event: @event_run_pipeline,
        uploader: Utils.module_to_string(uploader),
        id: id
      }),
      options
    )
  end

  defp oban_name, do: Keyword.get(Uppy.Config.oban(), :name, Uppy.Oban)
end
