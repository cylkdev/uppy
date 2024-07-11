defmodule Uppy.Uploader do
  alias Uppy.{
    Actions,
    Scheduler,
    Core
  }

  @one_day_seconds 86_400

  @one_hour_seconds 3_600

  ## Adapter API

  def queryable(uploader), do: uploader.queryable()

  def bucket(uploader), do: uploader.bucket()

  def resource_name(uploader), do: uploader.resource_name()

  def pipeline(uploader), do: uploader.pipeline()

  def storage_adapter(uploader), do: uploader.storage_adapter()

  def permanent_scope_adapter(uploader), do: uploader.permanent_scope_adapter()

  def temporary_scope_adapter(uploader), do: uploader.temporary_scope_adapter()

  def scheduler_adapter(uploader), do: uploader.scheduler_adapter()

  def action_adapter(uploader), do: uploader.action_adapter()

  ## Uploader API

  def find_object_and_update_upload_e_tag(uploader, params_or_schema_data, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)

    Core.find_object_and_update_upload_e_tag(
      action_adapter,
      storage_adapter,
      bucket,
      schema,
      params_or_schema_data,
      options
    )
  end

  def find_permanent_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    Core.find_permanent_upload(
      action_adapter,
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def find_completed_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    Core.find_completed_upload(
      action_adapter,
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def find_temporary_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    Core.find_temporary_upload(
      action_adapter,
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def presigned_part(uploader, params, part_number, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    Core.presigned_part(
      action_adapter,
      storage_adapter,
      temporary_scope_adapter,
      bucket,
      schema,
      params,
      part_number,
      options
    )
  end

  def find_parts(uploader, params, maybe_next_part_number_marker, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    Core.find_parts(
      action_adapter,
      temporary_scope_adapter,
      storage_adapter,
      bucket,
      schema,
      params,
      maybe_next_part_number_marker,
      options
    )
  end

  def complete_multipart_upload(uploader, params, parts, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    with {:ok, complete_multipart_upload} <-
           Core.complete_multipart_upload(
             action_adapter,
             storage_adapter,
             bucket,
             temporary_scope_adapter,
             schema,
             params,
             parts,
             options
           ),
         {:ok, job} <-
           Scheduler.enqueue(
             scheduler_adapter,
             :run_pipeline,
             %{
               uploader: uploader,
               id: complete_multipart_upload.schema_data.id
             },
             options[:schedule][:run_pipeline],
             options
           ) do
      {:ok, Map.put(complete_multipart_upload, :job, job)}
    end
  end

  def abort_multipart_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    operation = fn ->
      with {:ok, abort_multipart_upload} <-
             Core.abort_multipart_upload(
               action_adapter,
               storage_adapter,
               bucket,
               temporary_scope_adapter,
               schema,
               params,
               options
             ),
           {:ok, job} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :garbage_collect_object,
               %{
                 uploader: uploader,
                 key: abort_multipart_upload.schema_data.key
               },
               options[:schedule][:garbage_collect_object] || @one_day_seconds,
               options
             ) do
        {:ok, Map.put(abort_multipart_upload, :job, job)}
      end
    end

    Actions.transaction(action_adapter, operation, options)
  end

  def start_multipart_upload(uploader, partition_id, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    operation = fn ->
      with {:ok, start_multipart_upload} <-
             Core.start_multipart_upload(
               action_adapter,
               storage_adapter,
               bucket,
               temporary_scope_adapter,
               partition_id,
               schema,
               params,
               options
             ),
           {:ok, job} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :abort_multipart_upload,
               %{
                 uploader: uploader,
                 id: start_multipart_upload.schema_data.id
               },
               options[:schedule][:abort_multipart_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_multipart_upload, :job, job)}
      end
    end

    Actions.transaction(action_adapter, operation, options)
  end

  def run_pipeline(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    resource_name = resource_name(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)
    permanent_scope_adapter = permanent_scope_adapter(uploader)

    pipeline = pipeline(uploader)

    context = %{
      action_adapter: action_adapter,
      storage_adapter: storage_adapter,
      bucket: bucket,
      resource_name: resource_name,
      temporary_scope_adapter: temporary_scope_adapter,
      permanent_scope_adapter: permanent_scope_adapter
    }

    Core.run_pipeline(
      pipeline,
      context,
      schema,
      params,
      options
    )
  end

  def complete_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    with {:ok, complete_upload} <-
           Core.complete_upload(
             action_adapter,
             storage_adapter,
             bucket,
             temporary_scope_adapter,
             schema,
             params,
             options
           ),
         {:ok, job} <-
           Scheduler.enqueue(
             scheduler_adapter,
             :run_pipeline,
             %{
               uploader: uploader,
               id: complete_upload.schema_data.id
             },
             options[:schedule][:run_pipeline],
             options
           ) do
      {:ok, Map.put(complete_upload, :job, job)}
    end
  end

  def garbage_collect_object(uploader, key, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)

    Core.garbage_collect_object(action_adapter, storage_adapter, bucket, schema, key, options)
  end

  def abort_upload(uploader, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    operation = fn ->
      with {:ok, abort_upload} <-
             Core.abort_upload(action_adapter, temporary_scope_adapter, schema, params, options),
           {:ok, job} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :garbage_collect_object,
               %{
                 uploader: uploader,
                 bucket: bucket,
                 key: abort_upload.schema_data.key
               },
               options[:schedule][:garbage_collect_object] || @one_day_seconds,
               options
             ) do
        {:ok, Map.put(abort_upload, :job, job)}
      end
    end

    Actions.transaction(action_adapter, operation, options)
  end

  def start_upload(uploader, partition_id, params, options \\ []) do
    action_adapter = action_adapter(uploader)
    schema = queryable(uploader)

    storage_adapter = storage_adapter(uploader)
    bucket = bucket(uploader)
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    operation = fn ->
      with {:ok, start_upload_payload} <-
             Core.start_upload(
               action_adapter,
               storage_adapter,
               bucket,
               temporary_scope_adapter,
               partition_id,
               schema,
               params,
               options
             ),
           {:ok, job} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :abort_upload,
               %{
                 uploader: uploader,
                 bucket: bucket,
                 id: start_upload_payload.schema_data.id
               },
               options[:schedule][:abort_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_upload_payload, :job, job)}
      end
    end

    Actions.transaction(action_adapter, operation, options)
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.{
        Core,
        Uploader,
        Uploader.Provider
      }

      @behaviour Uppy.Adapter.Uploader

      @bucket Keyword.fetch!(opts, :bucket)

      @pipeline opts[:pipeline] || []

      @queryable Keyword.fetch!(opts, :queryable)

      @resource_name Keyword.fetch!(opts, :resource_name)

      @action_adapter opts[:action_adapter] || Uppy.Config.action_adapter()

      @scheduler_adapter opts[:scheduler_adapter] || Uppy.Adapters.Scheduler.Oban

      @storage_adapter opts[:storage_adapter] || Uppy.Adapters.Storage.S3

      @permanent_scope_adapter opts[:permanent_scope_adapter] ||
                                 Uppy.Adapters.PermanentScope

      @temporary_scope_adapter opts[:temporary_scope_adapter] ||
                                 Uppy.Adapters.TemporaryScope

      @options opts[:options] || []

      @impl true
      def pipeline, do: @pipeline

      @impl true
      def queryable, do: @queryable

      @impl true
      def bucket, do: @bucket

      @impl true
      def resource_name, do: @resource_name

      @impl true
      def storage_adapter, do: @storage_adapter

      @impl true
      def permanent_scope_adapter, do: @permanent_scope_adapter

      @impl true
      def temporary_scope_adapter, do: @temporary_scope_adapter

      @impl true
      def scheduler_adapter, do: @scheduler_adapter

      @impl true
      def action_adapter, do: @action_adapter

      @impl true
      def find_object_and_update_upload_e_tag(params_or_schema_data, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_object_and_update_upload_e_tag(
          __MODULE__,
          params_or_schema_data,
          options
        )
      end

      @impl true
      def find_permanent_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_permanent_upload(__MODULE__, params, options)
      end

      @impl true
      def find_completed_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_completed_upload(__MODULE__, params, options)
      end

      @impl true
      def find_temporary_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_temporary_upload(__MODULE__, params, options)
      end

      @impl true
      def presigned_part(params, part_number, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.presigned_part(__MODULE__, params, part_number, options)
      end

      @impl true
      def find_parts(params, maybe_next_part_number_marker, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_parts(__MODULE__, params, maybe_next_part_number_marker, options)
      end

      @impl true
      def complete_multipart_upload(params, parts, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.complete_multipart_upload(__MODULE__, params, parts, options)
      end

      @impl true
      def abort_multipart_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.abort_multipart_upload(__MODULE__, params, options)
      end

      @impl true
      def start_multipart_upload(partition_id, params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.start_multipart_upload(__MODULE__, partition_id, params, options)
      end

      @impl true
      def run_pipeline(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.run_pipeline(__MODULE__, params, options)
      end

      @impl true
      def complete_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.complete_upload(__MODULE__, params, options)
      end

      @impl true
      def garbage_collect_object(key, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.garbage_collect_object(__MODULE__, key, options)
      end

      @impl true
      def abort_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.abort_upload(__MODULE__, params, options)
      end

      @impl true
      def start_upload(partition_id, params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.start_upload(__MODULE__, partition_id, params, options)
      end
    end
  end
end
