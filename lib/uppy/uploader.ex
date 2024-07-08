defmodule Uppy.Uploader do
  alias Uppy.{
    Actions,
    Config,
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

  ## Uploader API

  def find_upload_object_and_update_e_tag(uploader, params_or_schema_data, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    schema = queryable(uploader)

    Core.find_upload_object_and_update_e_tag(
      storage_adapter,
      bucket,
      schema,
      params_or_schema_data,
      options
    )
  end

  def find_permanent_upload(uploader, params, options \\ []) do
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.find_permanent_upload(
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def find_confirmed_upload(uploader, params, options \\ []) do
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.find_confirmed_upload(
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def find_temporary_upload(uploader, params, options \\ []) do
    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.find_temporary_upload(
      temporary_scope_adapter,
      schema,
      params,
      options
    )
  end

  def presigned_part(uploader, params, part_number, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.presigned_part(
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
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.find_parts(
      temporary_scope_adapter,
      storage_adapter,
      bucket,
      schema,
      params,
      maybe_next_part_number_marker,
      options
    )
  end

  def confirm_multipart_upload(uploader, params, parts, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    schema = queryable(uploader)

    with {:ok, confirm_multipart_upload} <-
           Core.confirm_multipart_upload(
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
               id: confirm_multipart_upload.schema_data.id
             },
             nil,
             options
           ) do
      {:ok, Map.put(confirm_multipart_upload, :job, job)}
    end
  end

  def abort_multipart_upload(uploader, params, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    schema = queryable(uploader)

    operation = fn ->
      with {:ok, abort_multipart_upload} <-
             Core.abort_multipart_upload(
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
               scheduler_opts(options, :garbage_collect_object, @one_day_seconds),
               options
             ) do
        {:ok, Map.put(abort_multipart_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def start_multipart_upload(uploader, partition_id, params, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    schema = queryable(uploader)

    operation = fn ->
      with {:ok, start_multipart_upload} <-
             Core.start_multipart_upload(
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
               scheduler_opts(options, :abort_multipart_upload, @one_hour_seconds),
               options
             ) do
        {:ok, Map.put(start_multipart_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def run_pipeline(uploader, params, options \\ []) do
    pipeline = pipeline(uploader)

    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    resource_name = resource_name(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    permanent_scope_adapter = permanent_scope_adapter(uploader)

    schema = queryable(uploader)

    Core.run_pipeline(
      pipeline,
      storage_adapter,
      bucket,
      temporary_scope_adapter,
      permanent_scope_adapter,
      resource_name,
      schema,
      params,
      options
    )
  end

  def confirm_upload(uploader, params, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    schema = queryable(uploader)

    with {:ok, confirm_upload} <-
           Core.confirm_upload(
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
               id: confirm_upload.schema_data.id
             },
             scheduler_opts(options, :run_pipeline),
             options
           ) do
      {:ok, Map.put(confirm_upload, :job, job)}
    end
  end

  def garbage_collect_object(uploader, key, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    schema = queryable(uploader)

    Core.garbage_collect_object(storage_adapter, bucket, schema, key, options)
  end

  def abort_upload(uploader, params, options \\ []) do
    bucket = bucket(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    schema = queryable(uploader)

    operation = fn ->
      with {:ok, abort_upload} <-
             Core.abort_upload(temporary_scope_adapter, schema, params, options),
           {:ok, job} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :garbage_collect_object,
               %{
                 uploader: uploader,
                 bucket: bucket,
                 key: abort_upload.schema_data.key
               },
               scheduler_opts(options, :garbage_collect_object, @one_day_seconds),
               options
             ) do
        {:ok, Map.put(abort_upload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  def start_upload(uploader, partition_id, params, options \\ []) do
    storage_adapter = storage_adapter(uploader)

    bucket = bucket(uploader)

    scheduler_adapter = scheduler_adapter(uploader)

    temporary_scope_adapter = temporary_scope_adapter(uploader)

    schema = queryable(uploader)

    operation = fn ->
      with {:ok, start_upload_payload} <-
             Core.start_upload(
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
               scheduler_opts(options, :abort_upload, @one_hour_seconds),
               options
             ) do
        {:ok, Map.put(start_upload_payload, :job, job)}
      end
    end

    actions_transaction(operation, options)
  end

  defp actions_transaction(func, options) do
    Actions.transaction(Config.actions_adapter(), func, options)
  end

  defp scheduler_opts(options, key, default \\ nil) do
    options[:schedule][key] || default
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.{
        Adapter,
        Core,
        Uploader,
        Uploader.Provider
      }

      @behaviour Adapter.Uploader

      @bucket Keyword.fetch!(opts, :bucket)

      @pipeline opts[:pipeline] || []

      @queryable Keyword.fetch!(opts, :queryable)

      @resource_name Keyword.fetch!(opts, :resource_name)

      @scheduler_adapter opts[:scheduler_adapter] || Uppy.Adapters.Scheduler.Oban

      @storage_adapter opts[:storage_adapter] || Uppy.Adapters.Storage.S3

      @permanent_scope_adapter opts[:permanent_scope_adapter] ||
                                        Uppy.Adapters.PermanentScope

      @temporary_scope_adapter opts[:temporary_scope_adapter] ||
                                        Uppy.Adapters.TemporaryScope

      @options opts[:options] || []

      @impl Adapter.Uploader
      def pipeline, do: @pipeline

      @impl Adapter.Uploader
      def queryable, do: @queryable

      @impl Adapter.Uploader
      def bucket, do: @bucket

      @impl Adapter.Uploader
      def resource_name, do: @resource_name

      @impl Adapter.Uploader
      def storage_adapter, do: @storage_adapter

      @impl Adapter.Uploader
      def permanent_scope_adapter, do: @permanent_scope_adapter

      @impl Adapter.Uploader
      def temporary_scope_adapter, do: @temporary_scope_adapter

      @impl Adapter.Uploader
      def scheduler_adapter, do: @scheduler_adapter

      @impl Adapter.Uploader
      def find_upload_object_and_update_e_tag(params_or_schema_data, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_upload_object_and_update_e_tag(
          __MODULE__,
          params_or_schema_data,
          options
        )
      end

      @impl Adapter.Uploader
      def find_permanent_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_permanent_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def find_confirmed_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_confirmed_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def find_temporary_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_temporary_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def presigned_part(params, part_number, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.presigned_part(__MODULE__, params, part_number, options)
      end

      @impl Adapter.Uploader
      def find_parts(params, maybe_next_part_number_marker, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.find_parts(__MODULE__, params, maybe_next_part_number_marker, options)
      end

      @impl Adapter.Uploader
      def confirm_multipart_upload(params, parts, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.confirm_multipart_upload(__MODULE__, params, parts, options)
      end

      @impl Adapter.Uploader
      def abort_multipart_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.abort_multipart_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def start_multipart_upload(partition_id, params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.start_multipart_upload(__MODULE__, partition_id, params, options)
      end

      @impl Adapter.Uploader
      def run_pipeline(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.run_pipeline(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def confirm_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.confirm_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def garbage_collect_object(key, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.garbage_collect_object(__MODULE__, key, options)
      end

      @impl Adapter.Uploader
      def abort_upload(params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.abort_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def start_upload(partition_id, params, options \\ []) do
        options = Keyword.merge(@options, options)

        Uploader.start_upload(__MODULE__, partition_id, params, options)
      end

      defp raise_bucket_not_configured! do
        raise "bucket not configured for #{inspect(__MODULE__)}"
      end
    end
  end
end
