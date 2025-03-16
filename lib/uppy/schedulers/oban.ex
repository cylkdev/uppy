if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.Oban do
    @moduledoc false

    alias Uppy.Schedulers.Oban.WorkerAPI

    @behaviour Uppy.Scheduler

    @name Uppy.Oban

    @default_opts [
      notifier: Oban.Notifiers.PG
    ]

    def start_link(opts \\ []) do
      default_opts()
      |> Keyword.merge(opts)
      |> Keyword.put(:name, @name)
      |> Oban.start_link()
    end

    def child_spec(opts) do
      opts = Keyword.merge(default_opts(), opts)

      %{
        id: @name,
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    def insert(changeset, opts) do
      Oban.insert(@name, changeset, opts)
    end

    defp default_opts do
      Keyword.merge(@default_opts, Uppy.Config.oban())
    end

    # Scheduler API

    @impl Uppy.Scheduler
    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      WorkerAPI.enqueue_move_to_destination(bucket, query, id, dest_object, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      WorkerAPI.enqueue_abort_expired_multipart_upload(bucket, query, id, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      WorkerAPI.enqueue_abort_expired_upload(bucket, query, id, opts)
    end
  end
end
