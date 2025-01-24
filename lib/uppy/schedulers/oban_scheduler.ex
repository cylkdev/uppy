defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc false

  alias Uppy.Schedulers.ObanScheduler.Workers.{
    AbortExpiredMultipartUploadWorker,
    AbortExpiredUploadWorker,
    MoveToDestinationWorker
  }

  @behaviour Uppy.Scheduler

  defdelegate queue_move_to_destination(bucket, query, id, dest_object, schedule_in_or_at, opts),
    to: MoveToDestinationWorker

  defdelegate queue_abort_expired_multipart_upload(bucket, query, id, schedule_in_or_at, opts),
    to: AbortExpiredMultipartUploadWorker

  defdelegate queue_abort_expired_upload(bucket, query, id, schedule_in_or_at, opts),
    to: AbortExpiredUploadWorker
end
