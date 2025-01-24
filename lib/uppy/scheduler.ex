defmodule Uppy.Scheduler do
  @moduledoc false

  @callback queue_move_to_destination(
              bucket :: binary(),
              query :: term(),
              id :: term(),
              dest_object :: binary(),
              schedule_in_or_at :: non_neg_integer() | DateTime.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback queue_abort_expired_multipart_upload(
              bucket :: binary(),
              query :: term(),
              id :: term(),
              schedule_in_or_at :: non_neg_integer() | DateTime.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback queue_abort_expired_upload(
              bucket :: binary(),
              query :: term(),
              id :: term(),
              schedule_in_or_at :: non_neg_integer() | DateTime.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  def queue_move_to_destination(bucket, query, id, dest_object, schedule_in_or_at, opts) do
    adapter!(opts).queue_move_to_destination(
      bucket,
      query,
      id,
      dest_object,
      schedule_in_or_at,
      opts
    )
  end

  def queue_abort_expired_multipart_upload(bucket, query, id, schedule_in_or_at, opts) do
    adapter!(opts).queue_abort_expired_multipart_upload(
      bucket,
      query,
      id,
      schedule_in_or_at,
      opts
    )
  end

  def queue_abort_expired_upload(bucket, query, id, schedule_in_or_at, opts) do
    adapter!(opts).queue_abort_expired_upload(bucket, query, id, schedule_in_or_at, opts)
  end

  defp adapter!(opts) do
    opts[:scheduler_adapter] || Uppy.Schedulers.ObanScheduler
  end
end
