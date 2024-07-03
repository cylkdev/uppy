defmodule Uppy.Adapters.Scheduler.Oban.ExpiredUploadAborterWorker do
  @moduledoc false

  default_worker_opts = [
    queue: :expired_uploads,
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

  @event_prefix "uppy.expired_upload_aborter"
  @event_abort_upload "#{@event_prefix}.abort_upload"

  def perform(%Oban.Job{
        args: %{
          "event" => @event_abort_upload,
          "uploader" => uploader,
          "id" => id
        }
      }) do
    uploader
    |> Utils.to_existing_module!()
    |> Uploader.abort_upload(%{id: id})
  end

  def schedule_abort_upload(
        %{uploader: uploader, id: id},
        date_time_or_seconds,
        options
      ) do
    Oban.insert(
      oban_name(),
      new(%{
        event: @event_abort_upload,
        uploader: Utils.module_to_string(uploader),
        id: id
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

  defp oban_name, do: Keyword.get(Config.oban(), :name, Oban)
end
