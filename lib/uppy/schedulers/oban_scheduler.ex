if Code.ensure_loaded?(Oban) do
  defmodule Uppy.Schedulers.ObanScheduler do
    @moduledoc """
    ...
    """

    alias Uppy.{
      Core,
      Schedulers.ObanScheduler.ExpiredUploadWorker,
      Schedulers.ObanScheduler.GarbageCollectionWorker,
      Schedulers.ObanScheduler.PostProcessingWorker,
      Utils
    }

    @behaviour Uppy.Scheduler

    ## Scheduler

    @one_hour_seconds 3_600

    ## Encoding

    @compression_level 9
    @term_to_binary_minor_version 1

    ## Oban API

    @default_oban_name Uppy.Oban

    @default_oban_repo Uppy.Repo

    @default_queues [
      post_processing: 20,
      expired_upload: 10,
      garbage_collection: 5
    ]

    @default_oban_options (
      if Mix.env() === :test do
        [
          repo: @default_oban_repo,
          queues: @default_queues,
          testing: :manual
        ]
      else
        [
          repo: @default_oban_repo,
          queues: @default_queues
        ]
      end
    )

    def child_spec(opts \\ []) do
      name = opts[:name] || @default_oban_name

      %{
        id: name,
        start: {__MODULE__, :start_link, [name, Keyword.delete(opts, :name)]}
      }
    end

    def start_link(name \\ @default_oban_name, opts \\ []) do
      @default_oban_options
      |> Keyword.merge(opts)
      |> Keyword.put(:name, name)
      |> Oban.start_link()
    end

    ## Worker API

    @event_abort_multipart_upload "uppy.abort_multipart_upload"
    @event_abort_upload "uppy.abort_upload"
    @event_garbage_collect_upload "uppy.garbage_collect_upload"
    @event_process_upload "uppy.process_upload"

    @events %{
      abort_multipart_upload: @event_abort_multipart_upload,
      abort_upload: @event_abort_upload,
      garbage_collect_upload: @event_garbage_collect_upload,
      process_upload: @event_process_upload
    }

    @doc false
    def events, do: @events

    @doc """
    ...
    """
    def perform_garbage_collect_upload(
      bucket,
      id,
      encoded_query
    ) do
      query = decode_binary_to_term(encoded_query)

      Core.garbage_collect_upload(bucket, query, %{id: id}, [])
    end

    @doc """
    ...
    """
    @impl true
    def queue_garbage_collect_upload(
      bucket,
      query,
      id,
      opts
    ) do
      schedule = opts[:schedule_garbage_collect_upload] || @one_hour_seconds

      opts =
        opts
        |> Keyword.delete(:schedule_garbage_collect_upload)
        |> put_schedule(schedule)

      %{
        event: @event_garbage_collect_upload,
        bucket: bucket,
        id: id,
        query: encode_term_to_binary(query)
      }
      |> GarbageCollectionWorker.new(opts)
      |> insert_job(opts)
    end

    @doc """
    ...
    """
    def perform_abort_multipart_upload(
      bucket,
      encoded_query,
      id
    ) do
      query = decode_binary_to_term(encoded_query)

      Core.abort_multipart_upload(
        bucket,
        query,
        %{id: id},
        %{},
        status: :discarded
      )
    end

    @doc """
    ...
    """
    @impl true
    def queue_abort_multipart_upload(
      bucket,
      query,
      id,
      opts
    ) do
      schedule = opts[:schedule_abort_multipart_upload] || @one_hour_seconds

      opts =
        opts
        |> Keyword.delete(:schedule_abort_multipart_upload)
        |> put_schedule(schedule)

      %{
        event: @event_abort_multipart_upload,
        bucket: bucket,
        id: id,
        query: encode_term_to_binary(query)
      }
      |> ExpiredUploadWorker.new(opts)
      |> insert_job(opts)
    end

    @doc """
    ...
    """
    def perform_abort_upload(
      bucket,
      encoded_query,
      id
    ) do
      query = decode_binary_to_term(encoded_query)

      Core.abort_upload(
        bucket,
        query,
        %{id: id},
        %{},
        status: :discarded
      )
    end

    @doc """
    ...
    """
    @impl true
    def queue_abort_upload(
      bucket,
      query,
      id,
      opts
    ) do
      schedule = opts[:schedule_abort_upload] || @one_hour_seconds

      opts =
        opts
        |> Keyword.delete(:schedule_abort_upload)
        |> put_schedule(schedule)

      %{
        event: @event_abort_upload,
        bucket: bucket,
        id: id,
        query: encode_term_to_binary(query)
      }
      |> ExpiredUploadWorker.new(opts)
      |> insert_job(opts)
    end

    @doc """
    ...
    """
    def perform_process_upload(
      bucket,
      destination_object,
      encoded_query,
      id,
      pipeline
    ) do
      pipeline =
        if pipeline !== "" do
          Utils.string_to_existing_module!(pipeline)
        end

      query = decode_binary_to_term(encoded_query)

      Core.process_upload(
        bucket,
        destination_object,
        query,
        %{id: id},
        pipeline,
        []
      )
    end

    @doc """
    ...
    """
    @impl true
    def queue_process_upload(
      bucket,
      destination_object,
      query,
      id,
      pipeline_module,
      opts
    ) do
      schedule = opts[:schedule_process_upload] || @one_hour_seconds

      opts =
        opts
        |> Keyword.delete(:schedule_process_upload)
        |> put_schedule(schedule)

      %{
        event: @event_process_upload,
        bucket: bucket,
        destination_object: destination_object,
        id: id,
        query: encode_term_to_binary(query),
        pipeline: (if pipeline_module, do: Utils.module_to_string(pipeline_module), else: "")
      }
      |> PostProcessingWorker.new(opts)
      |> insert_job(opts)
    end

    defp insert_job(changeset, opts) do
      opts
      |> Keyword.get(:oban_name, @default_oban_name)
      |> Oban.insert(changeset, opts)
    end

    defp put_schedule(opts, %DateTime{} = schedule_at) do
      Keyword.put(opts, :schedule_at, schedule_at)
    end

    defp put_schedule(opts, schedule_in) do
      Keyword.put(opts, :schedule_in, schedule_in)
    end

    defp decode_binary_to_term(binary) do
      binary
      |> Base.decode64!()
      |> :erlang.binary_to_term()
    end

    defp encode_term_to_binary(term) do
      term
      |> :erlang.term_to_binary([
        :deterministic,
        compressed: @compression_level,
        minor_version: @term_to_binary_minor_version
      ])
      |> Base.encode64()
    end
  end
end
