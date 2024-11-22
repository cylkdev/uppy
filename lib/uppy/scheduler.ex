defmodule Uppy.Scheduler do
  @moduledoc """
  ...
  """

  @doc """
  ...
  """
  @callback queue_move_upload(
              bucket :: binary(),
              destination :: binary(),
              query :: term(),
              id :: term(),
              pipeline :: module(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback queue_abort_multipart_upload(
              bucket :: binary(),
              query :: term(),
              id :: term(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback queue_abort_upload(
              bucket :: binary(),
              query :: term(),
              id :: term(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  def queue_move_upload(bucket, destination, query, id, pipeline, opts) do
    adapter!(opts).queue_move_upload(bucket, destination, query, id, pipeline, opts)
  end

  def queue_abort_multipart_upload(bucket, query, id, opts) do
    adapter!(opts).queue_abort_multipart_upload(bucket, query, id, opts)
  end

  def queue_abort_upload(bucket, query, id, opts) do
    adapter!(opts).queue_abort_upload(bucket, query, id, opts)
  end

  defp adapter!(opts) do
    opts[:scheduler_adapter] || Uppy.Schedulers.ObanScheduler
  end
end
