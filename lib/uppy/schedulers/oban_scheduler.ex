if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler do
    @moduledoc false

    @behaviour Uppy.Scheduler

    alias Uppy.Schedulers.ObanScheduler

    defdelegate start_link(opts), to: Uppy.Schedulers.Oban

    defdelegate child_spec(opts), to: Uppy.Schedulers.Oban

    @impl Uppy.Scheduler
    defdelegate enqueue_move_to_destination(
                  bucket,
                  query,
                  id,
                  dest_object,
                  opts
                ),
                to: ObanScheduler.MoveToDestinationWorker

    @impl Uppy.Scheduler
    defdelegate enqueue_abort_expired_multipart_upload(
                  bucket,
                  query,
                  id,
                  opts
                ),
                to: ObanScheduler.AbortExpiredMultipartUploadWorker

    @impl Uppy.Scheduler
    defdelegate enqueue_abort_expired_upload(
                  bucket,
                  query,
                  id,
                  opts
                ),
                to: ObanScheduler.AbortExpiredUploadWorker
  end
end
