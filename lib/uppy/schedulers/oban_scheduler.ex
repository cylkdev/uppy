if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler do
    @moduledoc """
    ## Shared Options

    The following options are shared across most functions in this module:

      * `:oban_instances` - An enum where each key is a queue name and the
        value is the name of the Oban instance to use.

        For example:

        ```elixir
        [
          abort_expired_multipart_upload: MyApp.ObanA,
          abort_expired_upload: MyApp.ObanB,
          move_to_destination: MyApp.ObanC
        ]
        ```
    """

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
