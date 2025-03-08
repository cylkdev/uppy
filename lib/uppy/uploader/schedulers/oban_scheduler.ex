if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Uploader.Schedulers.ObanScheduler do
    @moduledoc false

    alias Uppy.Uploader.Schedulers.ObanScheduler.{
      AbortExpiredMultipartUploadWorker,
      AbortExpiredUploadWorker,
      MoveToDestinationWorker,
      WorkerAPI
    }

    @behaviour Uppy.Uploader.Scheduler

    @default_name __MODULE__

    @oban_opts [
      name: @default_name,
      repo: Uppy.Support.Repo,
      notifier: Oban.Notifiers.PG
    ]

    @move_to_destination_worker MoveToDestinationWorker

    @abort_expired_multipart_upload_worker AbortExpiredMultipartUploadWorker

    @abort_expired_upload_worker AbortExpiredUploadWorker

    @runtime_opts [
      name: @default_name,
      move_to_destination_worker: @move_to_destination_worker,
      abort_expired_multipart_upload_worker: @abort_expired_multipart_upload_worker,
      abort_expired_upload_worker: @abort_expired_upload_worker
    ]

    def start_link(opts \\ []) do
      opts
      |> oban_start_opts()
      |> Oban.start_link()
    end

    def child_spec(opts) do
      opts = oban_start_opts(opts)

      %{
        id: opts[:name],
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    defp oban_start_opts(opts) do
      @oban_opts
      |> Keyword.merge(module_config())
      |> Keyword.merge(opts)
      |> Keyword.put_new(:name, @default_name)
    end

    def insert(changeset, opts) do
      opts
      |> oban_name()
      |> Oban.insert(changeset, opts)
    end

    @impl Uppy.Uploader.Scheduler
    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      opts = Keyword.merge(@runtime_opts, opts)

      worker = opts[:move_to_destination_worker] || @move_to_destination_worker

      WorkerAPI.enqueue_move_to_destination(worker, bucket, query, id, dest_object, opts)
    end

    @impl Uppy.Uploader.Scheduler
    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      opts = Keyword.merge(@runtime_opts, opts)

      worker =
        opts[:abort_expired_multipart_upload_worker] || @abort_expired_multipart_upload_worker

      WorkerAPI.enqueue_abort_expired_multipart_upload(worker, bucket, query, id, opts)
    end

    @impl Uppy.Uploader.Scheduler
    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      opts = Keyword.merge(@runtime_opts, opts)

      worker = opts[:abort_expired_upload_worker] || @abort_expired_upload_worker

      WorkerAPI.enqueue_abort_expired_upload(worker, bucket, query, id, opts)
    end

    defp oban_name(opts) do
      opts[:name] || module_config()[:name] || @default_name
    end

    defp module_config do
      Uppy.Config.from_app_env(__MODULE__, [])
    end
  end
end
