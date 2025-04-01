if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler.WorkerAPI do
    @moduledoc """
    ## Shared Options

    The following options are shared across most functions in this module:

      * `:oban_workers` - An enum where each key is a queue name
        and the value is the Oban worker to use.

        For example:

        ```elixir
        [
          abort_expired_multipart_upload: MyApp.ObanWorkerA,
          abort_expired_upload: MyApp.ObanWorkerB,
          move_to_destination: MyApp.ObanWorkerC
        ]
        ```
    """

    alias Uppy.{
      Core,
      Schedulers.ObanScheduler.Instance,
      Schedulers.ObanScheduler.Workers
    }

    @abort_expired_multipart_upload "abort_expired_multipart_upload"
    @abort_expired_upload "abort_expired_upload"
    @move_to_destination "move_to_destination"

    @one_day :timer.hours(24)

    @expired :expired

    def perform(
      %{
        args: %{
          "event" => "uppy." <> @move_to_destination,
          "bucket" => bucket,
          "id" => id,
          "destination_object" => dest_object
        } = args,
        attempt: attempt,
        max_attempts: max_attempts
      },
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
        args: %{
          "event" => "uppy." <> @abort_expired_multipart_upload,
          "bucket" => bucket,
          "id" => id
        } = args,
        attempt: attempt,
        max_attempts: max_attempts
      },
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
        args: %{
          "event" => "uppy." <> @abort_expired_upload,
          "bucket" => bucket,
          "id" => id
        } = args,
        attempt: attempt,
        max_attempts: max_attempts
      },
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

    def enqueue_move_to_destination(bucket, query, id, dest_object, opts) do
      params =
        query
        |> query_to_args()
        |> Map.merge(%{
          event: event_name(@move_to_destination),
          id: id,
          bucket: bucket,
          destination_object: dest_object,
        })

      opts = put_schedule_opts(opts, opts[:move_to_destination][:schedule])

      @move_to_destination
      |> lookup_worker(Workers.MoveToDestinationWorker, opts)
      |> Instance.insert(params, opts)
    end

    def enqueue_abort_expired_multipart_upload(bucket, query, id, opts) do
      params =
        query
        |> query_to_args()
        |> Map.merge(%{
          event: event_name(@abort_expired_multipart_upload),
          bucket: bucket,
          id: id
        })

      opts = put_schedule_opts(opts, opts[:abort_expired_multipart_upload][:schedule] || @one_day)

      @abort_expired_multipart_upload
      |> lookup_worker(Workers.AbortExpiredMultipartUploadWorker, opts)
      |> Instance.insert(params, opts)
    end

    def enqueue_abort_expired_upload(bucket, query, id, opts) do
      params =
        query
        |> query_to_args()
        |> Map.merge(%{
          event: event_name(@abort_expired_upload),
          bucket: bucket,
          id: id
        })

      opts = put_schedule_opts(opts, opts[:abort_expired_upload][:schedule] || @one_day)

      @abort_expired_upload
      |> lookup_worker(Workers.AbortExpiredUploadWorker, opts)
      |> Instance.insert(params, opts)
    end

    defp event_name(name), do: "uppy.#{name}"

    defp query_to_args({source, query}), do: %{source: source, query: to_string(query)}
    defp query_to_args(query), do: %{query: to_string(query)}

    defp query_from_args(%{"source" => source, "query" => query}), do: {source, Uppy.Utils.string_to_existing_module(query)}
    defp query_from_args(%{"query" => query}), do: Uppy.Utils.string_to_existing_module(query)

    defp put_schedule_opts(opts, schedule) do
      case schedule do
        delay when is_integer(delay) ->
          if Keyword.has_key?(opts, :schedule_in) do
            opts
          else
            Keyword.put_new(opts, :schedule_in, delay)
          end

        datetime when is_struct(datetime, DateTime) ->
          if Keyword.has_key?(opts, :schedule_at) do
            opts
          else
            Keyword.put_new(opts, :schedule_at, datetime)
          end

        _ ->
          opts
      end
    end

    defp lookup_worker(queue, default, opts) do
      with {_, val} <-
        opts
        |> Keyword.get(:oban_workers, Uppy.Config.get_app_env(:oban_workers) || [])
        |> Enum.find(default, fn {k, _} -> to_string(k) === to_string(queue) end) do
        val
      end
    end
  end
end
