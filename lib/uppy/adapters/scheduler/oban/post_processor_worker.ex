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
  @event_move_temporary_to_permanent_upload "#{@event_prefix}.move_temporary_to_permanent_upload"

  def perform(%Oban.Job{
        args: %{
          "event" => @event_move_temporary_to_permanent_upload,
          "uploader" => uploader,
          "id" => id
        }
      }) do
    uploader
    |> Utils.to_existing_module!()
    |> Uploader.move_temporary_to_permanent_upload(%{id: id})
  end

  def queue_move_temporary_to_permanent_upload(%{uploader: uploader, id: id}, options) do
    Oban.insert(
      Uppy.Adapters.Scheduler.Oban.Config.name(),
      new(%{
        event: @event_move_temporary_to_permanent_upload,
        uploader: Utils.module_to_string(uploader),
        id: id
      }),
      options
    )
  end
end
