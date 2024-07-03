defmodule Uppy.Adapters.Scheduler.Oban.PostProcessorWorker do
  @moduledoc false

  default_worker_opts = [
    queue: :post_processing,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]
  ]

  compiled_worker_opts = Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @worker_opts Keyword.merge(default_worker_opts, compiled_worker_opts)

  use Oban.Worker, @worker_opts

  alias Uppy.{
    Config,
    Uploader,
    Utils
  }

  @type params :: Uppy.params()
  @type max_age_in_seconds :: Uppy.max_age_in_seconds()
  @type options :: Uppy.options()

  @type t_oban_insert_response :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | term()}

  @event_prefix "uppy.post_processor"
  @event_move_upload_to_permanent_storage "#{@event_prefix}.move_upload_to_permanent_storage"

  def perform(%Oban.Job{
        args: %{
          "event" => @event_move_upload_to_permanent_storage,
          "uploader" => uploader,
          "id" => id
        }
      }) do
    uploader
    |> Utils.to_existing_module!()
    |> Uploader.move_upload_to_permanent_storage(%{id: id})
  end

  def queue_move_upload_to_permanent_storage(%{uploader: uploader, id: id}, options) do
    Oban.insert(
      oban_name(),
      new(%{
        event: @event_move_upload_to_permanent_storage,
        uploader: Utils.module_to_string(uploader),
        id: id
      }),
      options
    )
  end

  defp oban_name, do: Keyword.get(Config.oban(), :name, Oban)
end
