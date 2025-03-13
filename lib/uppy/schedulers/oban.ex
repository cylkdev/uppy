if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.Oban do
    @moduledoc false

    alias Uppy.Schedulers.Oban.{
      AbortExpiredMultipartUploadWorker,
      AbortExpiredUploadWorker,
      MoveToDestinationWorker,
      WorkerAPI
    }

    @behaviour Uppy.Scheduler

    @default_name __MODULE__

    @default_opts [
      name: @default_name,
      notifier: Oban.Notifiers.PG,
      queues: [
        abort_expired_multipart_upload: 5,
        abort_expired_upload: 5,
        move_to_destination: 5
      ]
    ]

    @move_to_destination_worker MoveToDestinationWorker

    @abort_expired_multipart_upload_worker AbortExpiredMultipartUploadWorker

    @abort_expired_upload_worker AbortExpiredUploadWorker

    def alive?(name) do
      case Oban.whereis(name) do
        nil -> false
        pid -> Process.alive?(pid)
      end
    end

    def start_link(opts \\ []) do
      @default_opts
      |> Keyword.merge(opts)
      |> ensure_repo!()
      |> Oban.start_link()
    end

    defp ensure_repo!(opts) do
      if Keyword.has_key?(opts, :repo) do
        opts
      else
        raise ArgumentError, "Option `:repo` not found, got: #{inspect(opts)}"
      end
    end

    def child_spec(opts) do
      opts = Keyword.merge(@default_opts, opts)

      %{
        id: opts[:name],
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    def insert(changeset, opts) do
      opts
      |> oban_name()
      |> Oban.insert(changeset, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      opts
      |> Keyword.get(:worker, @move_to_destination_worker)
      |> WorkerAPI.enqueue_move_to_destination(bucket, query, id, dest_object, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      opts
      |> Keyword.get(:worker, @abort_expired_multipart_upload_worker)
      |> WorkerAPI.enqueue_abort_expired_multipart_upload(bucket, query, id, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      opts
      |> Keyword.get(:worker, @abort_expired_upload_worker)
      |> WorkerAPI.enqueue_abort_expired_upload(bucket, query, id, opts)
    end

    defp oban_name(opts) do
      opts[:scheduler][:name] || @default_name
    end
  end
end
