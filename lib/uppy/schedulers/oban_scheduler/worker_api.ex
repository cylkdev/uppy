defmodule Uppy.Schedulers.ObanScheduler.WorkerAPI do
  @moduledoc false

  alias Uppy.{
    Core,
    Schedulers.ObanScheduler
  }

  @event_move_to_destination "uppy.move_to_destination"
  @worker_move_to_destination ObanScheduler.MoveToDestinationWorker

  @event_abort_expired_multipart_upload "uppy.abort_expired_multipart_upload"
  @worker_abort_expired_multipart_upload ObanScheduler.AbortExpiredMultipartUploadWorker

  @event_abort_expired_upload "uppy.abort_expired_upload"
  @worker_abort_expired_upload ObanScheduler.AbortExpiredUploadWorker

  @events %{
    move_to_destination: @event_move_to_destination,
    abort_expired_multipart_upload: @event_abort_expired_multipart_upload,
    abort_expired_upload: @event_abort_expired_upload
  }

  # ---

  @default_oban_adapter Uppy.Schedulers.Oban

  @one_day :timer.hours(24)

  @default_worker_opts [
    max_attempts: 3
  ]

  @oban_job_opts ~w(
    max_attempts
    meta
    priority
    queue
    replace
    scheduled_at
    scheduled_in
    tags
    unique
  )a

  def events, do: @events

  def query_from_args(%{"source" => source, "query" => query}) do
    {source, Uppy.Utils.string_to_existing_module(query)}
  end

  def query_from_args(%{"query" => query}) do
    Uppy.Utils.string_to_existing_module(query)
  end

  def query_to_args({source, query}) do
    %{source: source, query: to_string(query)}
  end

  def query_to_args(query) do
    %{query: to_string(query)}
  end

  def perform(job, opts)

  def perform(
        %{
          attempt: attempt,
          args:
            %{
              "event" => @event_move_to_destination,
              "bucket" => bucket,
              "id" => id,
              "destination_object" => dest_object
            } = args
        },
        opts
      ) do
    opts = Keyword.merge(@default_worker_opts, opts)

    max_attempts = Keyword.fetch!(opts, :max_attempts)

    if attempt < max_attempts do
      Core.move_to_destination(
        bucket,
        query_from_args(args),
        %{id: id},
        dest_object,
        opts
      )
    else
      enqueue_move_to_destination(
        bucket,
        query_from_args(args),
        id,
        dest_object,
        opts
      )
    end
  end

  def perform(
        %{
          attempt: attempt,
          args:
            %{
              "event" => @event_abort_expired_multipart_upload,
              "bucket" => bucket,
              "id" => id
            } = args
        },
        opts
      ) do
    opts = Keyword.merge(@default_worker_opts, opts)

    max_attempts = Keyword.fetch!(opts, :max_attempts)

    if attempt < max_attempts do
      Core.abort_multipart_upload(
        bucket,
        query_from_args(args),
        %{id: id},
        %{state: :expired},
        opts
      )
    else
      enqueue_abort_expired_multipart_upload(
        bucket,
        query_from_args(args),
        id,
        opts
      )
    end
  end

  def perform(
        %{
          attempt: attempt,
          args:
            %{
              "event" => @event_abort_expired_upload,
              "bucket" => bucket,
              "id" => id
            } = args
        },
        opts
      ) do
    opts = Keyword.merge(@default_worker_opts, opts)

    max_attempts = Keyword.fetch!(opts, :max_attempts)

    if attempt < max_attempts do
      Core.abort_upload(
        bucket,
        query_from_args(args),
        %{id: id},
        %{state: :expired},
        opts
      )
    else
      enqueue_abort_expired_upload(
        bucket,
        query_from_args(args),
        id,
        opts
      )
    end
  end

  def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
    worker = opts[:worker_adapter] || @worker_move_to_destination

    opts =
      opts
      |> Keyword.delete(:schedule)
      |> put_schedule_opts(opts[:schedule][:move_to_destination])

    query
    |> query_to_args()
    |> Map.merge(%{
      event: @event_move_to_destination,
      bucket: bucket,
      destination_object: dest_object,
      id: id
    })
    |> worker.new(Keyword.take(opts, @oban_job_opts))
    |> oban_adapter(opts).insert(opts)
  end

  def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
    worker = opts[:worker_adapter] || @worker_abort_expired_multipart_upload

    opts =
      opts
      |> Keyword.delete(:schedule)
      |> put_schedule_opts(opts[:schedule][:abort_expired_multipart_upload] || @one_day)

    query
    |> query_to_args()
    |> Map.merge(%{
      event: @event_abort_expired_multipart_upload,
      bucket: bucket,
      id: id
    })
    |> worker.new(Keyword.take(opts, @oban_job_opts))
    |> oban_adapter(opts).insert(opts)
  end

  def enqueue_abort_expired_upload(bucket, query, id, opts) do
    worker = opts[:worker_adapter] || @worker_abort_expired_upload

    opts =
      opts
      |> Keyword.delete(:schedule)
      |> put_schedule_opts(opts[:schedule][:abort_expired_upload] || @one_day)

    query
    |> query_to_args()
    |> Map.merge(%{
      event: @event_abort_expired_upload,
      bucket: bucket,
      id: id
    })
    |> worker.new(Keyword.take(opts, @oban_job_opts))
    |> oban_adapter(opts).insert(opts)
  end

  defp put_schedule_opts(opts, delay) do
    case delay do
      delay when is_integer(delay) ->
        if Keyword.has_key?(opts, :schedule_in) do
          opts
        else
          Keyword.put(opts, :schedule_in, delay)
        end

      dt when is_struct(dt, DateTime) ->
        if Keyword.has_key?(opts, :schedule_at) do
          opts
        else
          Keyword.put(opts, :schedule_at, dt)
        end

      _ ->
        opts
    end
  end

  defp oban_adapter(opts) do
    opts[:oban_adapter] || @default_oban_adapter
  end
end
