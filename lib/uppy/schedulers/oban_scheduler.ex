defmodule Uppy.Schedulers.ObanScheduler do
  @moduledoc false
  alias Uppy.Schedulers.ObanScheduler.Workers

  @behaviour Uppy.Scheduler

  @spec queue_move_to_destination(
          bucket :: binary(),
          query :: term(),
          id :: integer() | binary(),
          dest_object :: binary(),
          schedule_in_or_at :: non_neg_integer() | DateTime.t(),
          opts :: keyword()
        ) :: {:ok, Oban.Job.t()} | {:error, term()}
  defdelegate queue_move_to_destination(bucket, query, id, dest_object, schedule_in_or_at, opts),
    to: Workers.MoveToDestinationWorker

  @spec queue_abort_expired_multipart_upload(
          bucket :: binary(),
          query :: term(),
          id :: integer() | binary(),
          schedule_in_or_at :: non_neg_integer() | DateTime.t(),
          opts :: keyword()
        ) :: {:ok, Oban.Job.t()} | {:error, term()}
  defdelegate queue_abort_expired_multipart_upload(bucket, query, id, schedule_in_or_at, opts),
    to: Workers.AbortExpiredMultipartUploadWorker

  @spec queue_abort_expired_upload(
          bucket :: binary(),
          query :: term(),
          id :: integer() | binary(),
          schedule_in_or_at :: non_neg_integer() | DateTime.t(),
          opts :: keyword()
        ) :: {:ok, Oban.Job.t()} | {:error, term()}
  defdelegate queue_abort_expired_upload(bucket, query, id, schedule_in_or_at, opts),
    to: Workers.AbortExpiredUploadWorker
end
