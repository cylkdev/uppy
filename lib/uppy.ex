defmodule Uppy do
  @moduledoc """
  Documentation for `Uppy`.
  """

  @type adapter :: module()
  @type schema :: module()

  @type params :: map()
  @type body :: term()
  @type max_age_in_seconds :: non_neg_integer()
  @type options :: Keyword.t()

  @type http_method ::
          :get
          | :head
          | :post
          | :put
          | :delete
          | :connect
          | :options
          | :trace
          | :patch

  @type bucket :: String.t()
  @type prefix :: String.t()
  @type object :: String.t()

  @type e_tag :: String.t()
  @type upload_id :: String.t()
  @type marker :: String.t()
  @type maybe_marker :: marker() | nil
  @type part_number :: non_neg_integer()
  @type part :: {part_number(), e_tag()}
  @type parts :: list(part())

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      app = opts[:app]
      queryable = opts[:queryable]

      adapter_config = if app, do: Application.compile_env(app, __MODULE__, []), else: []

      get_opt_or_config = fn key, default -> opts[key] || adapter_config[key] || default end

      if is_nil(queryable) do
        raise "option `:queryable` not set in module #{__MODULE__}."
      end

      alias Uppy.{
        Adapter,
        Core,
        Uploader,
        Uploader.Provider
      }

      @behaviour Adapter.Uploader

      @bucket get_opt_or_config.(:bucket, nil)
      @resource opts[:resource]
      @scheduler get_opt_or_config.(:scheduler, nil)
      @storage get_opt_or_config.(:storage, nil)
      @temporary_object_key get_opt_or_config.(
                              :temporary_object_key,
                              Uppy.Adapters.ObjectKey.TemporaryObject
                            )
      @permanent_object_key get_opt_or_config.(
                              :permanent_object_key,
                              Uppy.Adapters.ObjectKey.PermanentObject
                            )
      @queryable_primary_key_source opts[:queryable_primary_key_source] || :id
      @parent_schema opts[:parent_schema]
      @parent_association_source opts[:parent_association_source]
      @owner_schema get_opt_or_config.(:owner_schema, nil)
      @owner_association_source get_opt_or_config.(
                                  :owner_association_source,
                                  nil
                                )
      @owner_primary_key_source get_opt_or_config.(
                                  :owner_primary_key_source,
                                  :id
                                )

      @queryable queryable

      @pipeline get_opt_or_config.(:pipeline, Uppy.Config.pipeline())

      @core Core.validate!(
              bucket: @bucket,
              resource: @resource,
              scheduler: @scheduler,
              storage: @storage,
              queryable: @queryable,
              queryable_primary_key_source: @queryable_primary_key_source,
              owner_schema: @owner_schema,
              owner_association_source: @owner_association_source,
              owner_primary_key_source: @owner_primary_key_source,
              parent_schema: @parent_schema,
              parent_association_source: @parent_association_source,
              permanent_object_key: @permanent_object_key,
              temporary_object_key: @temporary_object_key
            )

      @options Keyword.get(opts, :options, [])

      @impl Adapter.Uploader
      def core, do: @core

      @impl Adapter.Uploader
      def core(field), do: Uploader.core(__MODULE__, field)

      @impl Adapter.Uploader
      def pipeline, do: @pipeline

      @impl Adapter.Uploader
      def presigned_part(params, part_number) do
        Uploader.presigned_part(__MODULE__, params, part_number, @options)
      end

      @impl Adapter.Uploader
      def find_parts(params, next_part_number_marker \\ nil) do
        Uploader.find_parts(__MODULE__, params, next_part_number_marker, @options)
      end

      @impl Adapter.Uploader
      def complete_multipart_upload(params, parts) do
        Uploader.complete_multipart_upload(__MODULE__, params, parts, @options)
      end

      @impl Adapter.Uploader
      def abort_multipart_upload(params) do
        Uploader.abort_multipart_upload(__MODULE__, params, @options)
      end

      @impl Adapter.Uploader
      def start_multipart_upload(upload_params, params \\ %{}) do
        Uploader.start_multipart_upload(__MODULE__, upload_params, params, @options)
      end

      @impl Adapter.Uploader
      def move_temporary_to_permanent_upload(params) do
        Uploader.move_temporary_to_permanent_upload(__MODULE__, params, @options)
      end

      @impl Adapter.Uploader
      def complete_upload(params) do
        Uploader.complete_upload(__MODULE__, params, @options)
      end

      @impl Adapter.Uploader
      def garbage_collect_object(key) do
        Uploader.garbage_collect_object(__MODULE__, key, @options)
      end

      @impl Adapter.Uploader
      def abort_upload(params) do
        Uploader.abort_upload(__MODULE__, params, @options)
      end

      @impl Adapter.Uploader
      def start_upload(upload_params, params \\ %{}) do
        Uploader.start_upload(__MODULE__, upload_params, params, @options)
      end
    end
  end
end
