defmodule Uppy.Scheduler do
  @moduledoc false

  @default_adapter Uppy.Schedulers.ObanScheduler

  @callback enqueue_move_to_destination(
              bucket :: binary(),
              query :: term(),
              id :: integer() | binary(),
              dest_object :: binary(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback enqueue_abort_expired_multipart_upload(
              bucket :: binary(),
              query :: term(),
              id :: integer() | binary(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback enqueue_abort_expired_upload(
              bucket :: binary(),
              query :: term(),
              id :: integer() | binary(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  Enqueues a job to move a file to a new location after the
  specified amount of time.
  """
  def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
    adapter(opts).enqueue_move_to_destination(bucket, query, id, dest_object, opts)
  end

  @doc """
  Enqueues a job to abort a multipart upload after the
  specified amount of time.
  """
  def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
    adapter(opts).enqueue_abort_expired_multipart_upload(bucket, query, id, opts)
  end

  @doc """
  Enqueues a job to abort a non-multipart upload after the
  specified amount of time.
  """
  def enqueue_abort_expired_upload(bucket, query, id, opts) do
    adapter(opts).enqueue_abort_expired_upload(bucket, query, id, opts)
  end

  defp adapter(opts) do
    opts[:scheduler_adapter] || @default_adapter
  end
end
