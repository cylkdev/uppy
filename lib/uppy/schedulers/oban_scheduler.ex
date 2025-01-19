defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc false

  alias Uppy.Schedulers.ObanScheduler.Workers.{
    AbortExpiredMultipartUploadWorker,
    AbortExpiredUploadWorker,
    PostProessingWorker
  }

  defdelegate queue_move_to_destination(bucket, query, id, dest_object, opts),
    to: PostProessingWorker

  defdelegate queue_abort_expired_multipart_upload(bucket, query, id, opts),
    to: AbortExpiredMultipartUploadWorker

  defdelegate queue_abort_expired_upload(bucket, query, id, opts),
    to: AbortExpiredUploadWorker
end
