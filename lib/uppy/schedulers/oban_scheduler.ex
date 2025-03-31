if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler do
    @moduledoc false

    alias Uppy.Schedulers.ObanScheduler.{
      Instance,
      WorkerAPI
    }

    @behaviour Uppy.Scheduler

    def start_link(opts \\ []) do
      Instance.start_link(opts)
    end

    def child_spec(opts) do
      Instance.child_spec(opts)
    end

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
