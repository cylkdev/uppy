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

    @default_name __MODULE__

    @default_opts [
      name: @default_name
    ]

    def start_link(opts \\ []) do
      opts
      |> Keyword.put_new(:name, @default_name)
      |> Instance.start_link()
    end

    def child_spec(opts) do
      opts
      |> Keyword.put_new(:name, @default_name)
      |> Instance.child_spec()
    end

    @impl Uppy.Scheduler
    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      opts = ensure_scheduler_opts(opts)

      WorkerAPI.enqueue_move_to_destination(bucket, query, id, dest_object, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      opts = ensure_scheduler_opts(opts)

      WorkerAPI.enqueue_abort_expired_multipart_upload(bucket, query, id, opts)
    end

    @impl Uppy.Scheduler
    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      opts = ensure_scheduler_opts(opts)

      WorkerAPI.enqueue_abort_expired_upload(bucket, query, id, opts)
    end

    defp ensure_scheduler_opts(opts) do
      default_opts = default_opts()

      Keyword.update(opts, :scheduler, default_opts, &Keyword.merge(default_opts, &1))
    end

    defp default_opts do
      Keyword.merge(@default_opts, Uppy.Config.get_app_env(:scheduler) || [])
    end
  end
end
