defmodule Uppy.Uploader.Scheduler do
  @moduledoc false

  @type query :: term()
  @type id :: integer() | binary()
  @type bucket :: binary()
  @type object :: binary()
  @type options :: keyword()

  @default_adapter Uppy.Uploader.Schedulers.ObanScheduler

  @callback enqueue_move_to_destination(
              bucket :: bucket(),
              query :: query(),
              id :: id(),
              dest_object :: object(),
              opts :: options()
            ) :: {:ok, term()} | {:error, term()}

  @callback enqueue_abort_expired_multipart_upload(
              bucket :: bucket(),
              query :: query(),
              id :: id(),
              opts :: options()
            ) :: {:ok, term()} | {:error, term()}

  @callback enqueue_abort_expired_upload(
              bucket :: bucket(),
              query :: query(),
              id :: id(),
              opts :: options()
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
