defmodule Uppy.Scheduler do
  @moduledoc """
  ...
  """

  alias Uppy.Config

  @default_scheduler_adapter Uppy.Schedulers.Oban

  def queue_garbage_collect_object(
        bucket,
        schema,
        key,
        schedule_at_or_schedule_in,
        opts
      ) do
    bucket
    |> adapter!(opts).queue_garbage_collect_object(
      schema,
      key,
      schedule_at_or_schedule_in,
      opts
    )
    |> handle_response()
  end

  def queue_abort_multipart_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        opts
      ) do
    bucket
    |> adapter!(opts).queue_abort_multipart_upload(
      schema,
      id,
      schedule_at_or_schedule_in,
      opts
    )
    |> handle_response()
  end

  def queue_abort_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        opts
      ) do
    bucket
    |> adapter!(opts).queue_abort_upload(
      schema,
      id,
      schedule_at_or_schedule_in,
      opts
    )
    |> handle_response()
  end

  def queue_process_upload(
        pipeline_module,
        bucket,
        resource,
        schema,
        id,
        nil_or_schedule_at_or_schedule_in,
        opts
      ) do
    pipeline_module
    |> adapter!(opts).queue_process_upload(
      bucket,
      resource,
      schema,
      id,
      nil_or_schedule_at_or_schedule_in,
      opts
    )
    |> handle_response()
  end

  defp adapter!(opts) do
    Keyword.get(opts, :scheduler_adapter, Config.scheduler_adapter()) ||
      @default_scheduler_adapter
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, _} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, term()}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end
end
