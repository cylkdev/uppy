if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Uploader.Engines.ObanEngine do
    @moduledoc false

    @behaviour Uppy.Uploader.Engine

    alias Uppy.Uploader.Engines.ObanEngine.{
      ExpiredMultipartUploadWorker,
      ExpiredUploadWorker,
      MoveToDestinationWorker,
      WorkerAPI
    }

    @name __MODULE__

    @default_options [
      name: @name,
      notifier: Oban.Notifiers.PG
    ]

    @worker_abort_expired_multipart_upload ExpiredMultipartUploadWorker

    @worker_abort_expired_upload ExpiredUploadWorker

    @worker_move_to_destination MoveToDestinationWorker

    def start_link(opts \\ []) do
      opts
      |> configure_opts()
      |> Oban.start_link()
    end

    def child_spec(opts \\ []) do
      opts = configure_opts(opts)

      %{
        id: opts[:name],
        start: {__MODULE__, :start_link, [opts]}
      }
    end

    defp configure_opts(opts) do
      @default_options
      |> Keyword.merge(Uppy.Config.from_app_env(__MODULE__))
      |> Keyword.merge(opts)
      |> Keyword.put_new(:name, @name)
      |> ensure_repo_configured!()
    end

    defp ensure_repo_configured!(opts) do
      if is_nil(opts[:repo]) do
        raise ArgumentError, "Option `:repo` required, got: #{inspect(opts, pretty: true)}"
      end

      opts
    end

    def insert(changeset, opts \\ []) do
      opts
      |> Keyword.get(:name, @name)
      |> Oban.insert(changeset, Keyword.delete(opts, :name))
    end

    @impl Uppy.Uploader.Engine
    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      opts
      |> Keyword.get(:worker_adapter, @worker_move_to_destination)
      |> WorkerAPI.enqueue_move_to_destination(bucket, query, id, dest_object, opts)
    end

    @impl Uppy.Uploader.Engine
    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      opts
      |> Keyword.get(:worker_adapter, @worker_abort_expired_multipart_upload)
      |> WorkerAPI.enqueue_abort_expired_multipart_upload(bucket, query, id, opts)
    end

    @impl Uppy.Uploader.Engine
    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      opts
      |> Keyword.get(:worker_adapter, @worker_abort_expired_upload)
      |> WorkerAPI.enqueue_abort_expired_upload(bucket, query, id, opts)
    end
  end
end
