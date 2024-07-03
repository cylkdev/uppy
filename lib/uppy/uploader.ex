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

  def provider(uploader), do: uploader.provider()

  def queryable(uploader), do: uploader.queryable()

  def pipeline(uploader), do: uploader.pipeline()

  ## Uploader API

  def move_upload_to_permanent_storage(uploader, params, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    pipeline = pipeline(uploader)

    Core.move_upload_to_permanent_storage(provider, schema, params, pipeline, options)
  end

  def complete_upload(uploader, params, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    %{scheduler_adapter: scheduler_adapter} = provider

    with {:ok, complete_upload_payload} <-
           Core.complete_upload(provider, schema, params, options),
         {:ok, scheduler_payload} <-
           Scheduler.enqueue(
             scheduler_adapter,
             :move_upload_to_permanent_storage,
             %{
               uploader: uploader,
               id: complete_upload_payload.schema_data.id
             },
             nil,
             options
           ) do
      {:ok,
       Map.put(
         complete_upload_payload,
         :move_upload_to_permanent_storage_job,
         scheduler_payload
       )}
    end
  end

  def delete_aborted_upload_object(uploader, key, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    Core.delete_aborted_upload_object(provider, schema, key, options)
  end

  def abort_upload(uploader, params, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    %{scheduler_adapter: scheduler_adapter} = provider

    operation = fn ->
      with {:ok, abort_upload_payload} <-
             Core.abort_upload(provider, schema, params, options),
           {:ok, scheduler_payload} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :delete_aborted_upload_object,
               %{
                 uploader: uploader,
                 key: abort_upload_payload.schema_data.key
               },
               options[:scheduler][:delete_aborted_upload_object] || @one_day_seconds,
               options
             ) do
        {:ok,
         Map.put(
           abort_upload_payload,
           :delete_aborted_upload_object_job,
           scheduler_payload
         )}
      end
    end

    actions_transaction(operation, options)
  end

  def start_upload(uploader, upload_params, create_params \\ %{}, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    %{
      queryable_primary_key_source: queryable_primary_key_source,
      scheduler_adapter: scheduler_adapter
    } = provider

    operation = fn ->
      with {:ok, start_upload_payload} <-
             Core.start_upload(provider, schema, upload_params, create_params, options),
           id <-
             Map.fetch!(start_upload_payload.schema_data, queryable_primary_key_source),
           {:ok, scheduler_payload} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :abort_upload,
               %{uploader: uploader, id: id},
               options[:scheduler][:abort_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_upload_payload, :abort_upload_job, scheduler_payload)}
      end
    end

    actions_transaction(operation, options)
  end

  def start_multipart_upload(uploader, upload_params, create_params \\ %{}, options \\ []) do
    provider = provider(uploader)

    schema = queryable(uploader)

    %{
      queryable_primary_key_source: queryable_primary_key_source,
      scheduler_adapter: scheduler_adapter
    } = provider

    operation = fn ->
      with {:ok, start_upload_payload} <-
             Core.start_multipart_upload(provider, schema, upload_params, create_params, options),
           id <-
             Map.fetch!(start_upload_payload.schema_data, queryable_primary_key_source),
           {:ok, scheduler_payload} <-
             Scheduler.enqueue(
               scheduler_adapter,
               :abort_upload,
               %{uploader: uploader, id: id},
               options[:scheduler][:abort_upload] || @one_hour_seconds,
               options
             ) do
        {:ok, Map.put(start_upload_payload, :abort_upload_job, scheduler_payload)}
      end
    end

    actions_transaction(operation, options)
  end

  defp actions_transaction(func, options) do
    Actions.transaction(Config.actions_adapter(), func, options)
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      app = opts[:app]
      queryable = opts[:queryable]

      if is_nil(queryable) do
        raise "option `:queryable` not set in module #{__MODULE__}."
      end

      adapter_config = if app, do: Application.compile_env(app, __MODULE__, []), else: []
      get_opt_or_config = fn key, default -> opts[key] || adapter_config[key] || default end

      alias Uppy.{
        Adapter,
        Uploader,
        Uploader.Provider
      }

      @behaviour Adapter.Uploader

      @bucket get_opt_or_config.(:bucket, nil)
      @resource_name opts[:resource_name]
      @scheduler_adapter get_opt_or_config.(:scheduler_adapter, nil)
      @storage_adapter get_opt_or_config.(:storage_adapter, nil)
      @temporary_object_key_adapter get_opt_or_config.(
                                      :temporary_object_key_adapter,
                                      Uppy.Adapters.ObjectKey.TemporaryObject
                                    )
      @permanent_object_key_adapter get_opt_or_config.(
                                      :permanent_object_key_adapter,
                                      Uppy.Adapters.ObjectKey.PermanentObject
                                    )
      @queryable_primary_key_source opts[:queryable_primary_key_source] || :id
      @parent_schema opts[:parent_schema]
      @parent_association_source opts[:parent_association_source]
      @owner_schema get_opt_or_config.(:owner_schema, nil)
      @queryable_owner_association_source get_opt_or_config.(
                                         :queryable_owner_association_source,
                                         nil
                                       )
      @owner_primary_key_source get_opt_or_config.(
                                         :owner_primary_key_source,
                                         :id
                                       )

      @queryable queryable
      @pipeline get_opt_or_config.(:pipeline, Uppy.Config.pipeline())

      @provider Core.validate!(
                  bucket: @bucket,
                  resource_name: @resource_name,
                  scheduler_adapter: @scheduler_adapter,
                  storage_adapter: @storage_adapter,
                  permanent_object_key_adapter: @permanent_object_key_adapter,
                  temporary_object_key_adapter: @temporary_object_key_adapter,
                  queryable_primary_key_source: @queryable_primary_key_source,
                  owner_schema: @owner_schema,
                  queryable_owner_association_source: @queryable_owner_association_source,
                  owner_primary_key_source: @owner_primary_key_source,
                  parent_schema: @parent_schema,
                  parent_association_source: @parent_association_source
                )

      @impl Adapter.Uploader
      def provider, do: @provider

      @impl Adapter.Uploader
      def queryable, do: @queryable

      @impl Adapter.Uploader
      def pipeline, do: @pipeline

      @impl Adapter.Uploader
      def move_upload_to_permanent_storage(params, options \\ []) do
        Uploader.move_upload_to_permanent_storage(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def complete_upload(params, options \\ []) do
        Uploader.complete_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def delete_aborted_upload_object(key, options \\ []) do
        Uploader.delete_aborted_upload_object(__MODULE__, key, options)
      end

      @impl Adapter.Uploader
      def abort_upload(params, options \\ []) do
        Uploader.abort_upload(__MODULE__, params, options)
      end

      @impl Adapter.Uploader
      def start_upload(uploader, upload_params, create_params \\ %{}, options \\ []) do
        Uploader.start_upload(__MODULE__, upload_params, create_params, options)
      end

      @impl Adapter.Uploader
      def start_multipart_upload(uploader, upload_params, create_params \\ %{}, options \\ []) do
        Uploader.start_multipart_upload(__MODULE__, upload_params, create_params, options)
      end
    end
  end
end
