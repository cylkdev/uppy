if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.WorkerAPI do
    @moduledoc false

    alias Uppy.{
      Core,
      Schedulers.ObanScheduler.Router
    }

    # ---

    @event_abort_expired_multipart_upload "uppy.abort_expired_multipart_upload"
    @event_abort_expired_upload "uppy.abort_expired_upload"
    @event_move_to_destination "uppy.move_to_destination"

    @expired :expired

    @one_day :timer.hours(24)

    # Worker API

    def perform(job, opts \\ [])

    def perform(
          %{
            attempt: attempt,
            max_attempts: max_attempts,
            args:
              %{
                "event" => @event_move_to_destination,
                "bucket" => bucket,
                "id" => id,
                "destination_object" => dest_object
              } = args
          } = _job,
          opts
        ) do
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
            max_attempts: max_attempts,
            args:
              %{
                "event" => @event_abort_expired_multipart_upload,
                "bucket" => bucket,
                "id" => id
              } = args
          } = _job,
          opts
        ) do
      if attempt < max_attempts do
        Core.abort_multipart_upload(
          bucket,
          query_from_args(args),
          %{id: id},
          %{state: @expired},
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
            max_attempts: max_attempts,
            args:
              %{
                "event" => @event_abort_expired_upload,
                "bucket" => bucket,
                "id" => id
              } = args
          } = _job,
          opts
        ) do
      if attempt < max_attempts do
        Core.abort_upload(
          bucket,
          query_from_args(args),
          %{id: id},
          %{state: @expired},
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

    # Scheduler API

    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      schedule = opts[:move_to_destination][:schedule]

      %{
        event: @event_move_to_destination,
        bucket: bucket,
        destination_object: dest_object,
        id: id
      }
      |> Map.merge(query_to_args(query))
      |> Router.lookup_worker(:move_to_destination).new(job_opts(opts, schedule))
      |> Router.lookup_instance(:move_to_destination).insert(opts)
    end

    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      schedule = opts[:abort_expired_multipart_upload][:schedule] || @one_day

      %{
        event: @event_abort_expired_multipart_upload,
        bucket: bucket,
        id: id
      }
      |> Map.merge(query_to_args(query))
      |> Router.lookup_worker(:abort_expired_multipart_upload).new(job_opts(opts, schedule))
      |> Router.lookup_instance(:abort_expired_multipart_upload).insert(opts)
    end

    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      schedule = opts[:abort_expired_upload][:schedule] || @one_day

      %{
        event: @event_abort_expired_upload,
        bucket: bucket,
        id: id
      }
      |> Map.merge(query_to_args(query))
      |> Router.lookup_worker(:abort_expired_upload).new(job_opts(opts, schedule))
      |> Router.lookup_instance(:abort_expired_upload).insert(opts)
    end

    defp job_opts(opts, schedule) do
      opts |> Keyword.get(:job, []) |> put_schedule_opts(schedule)
    end

    defp query_from_args(%{"source" => source, "query" => query}) do
      {source, Uppy.Utils.string_to_existing_module(query)}
    end

    defp query_from_args(%{"query" => query}) do
      Uppy.Utils.string_to_existing_module(query)
    end

    defp query_to_args({source, query}) do
      %{source: source, query: to_string(query)}
    end

    defp query_to_args(query) do
      %{query: to_string(query)}
    end

    defp put_schedule_opts(opts, delay) do
      case delay do
        delay when is_integer(delay) ->
          if Keyword.has_key?(opts, :schedule_in) do
            opts
          else
            Keyword.put_new(opts, :schedule_in, delay)
          end

        dt when is_struct(dt, DateTime) ->
          if Keyword.has_key?(opts, :schedule_at) do
            opts
          else
            Keyword.put_new(opts, :schedule_at, dt)
          end

        _ ->
          opts
      end
    end
  end
end
