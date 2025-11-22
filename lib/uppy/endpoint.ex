defmodule Uppy.Endpoint do
  alias Uppy.{
    Action,
    Core,
    Store,
    Scheduler
  }

  @conditions_keys [
    :content_encoding,
    :content_length,
    :content_type,
    :expires,
    :min_size,
    :max_size
  ]

  @callback bucket() :: String.t()

  @callback conditions() :: map()

  @callback schema() :: module()

  @callback options() :: Keyword.t()

  # ---

  @callback pre_sign(request_key :: String.t(), params :: map()) ::
              {:ok, term()} | {:error, term()}

  @callback pre_sign_part(
              request_key :: String.t(),
              upload_id :: String.t(),
              part_number :: integer(),
              params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback complete_upload(
              request_key :: String.t(),
              find_params :: map(),
              update_params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback abort_upload(
              request_key :: String.t(),
              find_params :: map(),
              update_params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback create_upload(
              stored_key :: String.t(),
              request_key :: String.t(),
              filename :: String.t(),
              params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback complete_multipart_upload(
              request_key :: String.t(),
              upload_id :: String.t(),
              parts :: list(),
              find_params :: map(),
              update_params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback find_parts(
              request_key :: String.t(),
              upload_id :: String.t(),
              params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback abort_multipart_upload(
              request_key :: String.t(),
              upload_id :: String.t(),
              find_params :: map(),
              update_params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @callback create_multipart_upload(
              stored_key :: String.t(),
              request_key :: String.t(),
              filename :: String.t(),
              params :: map()
            ) :: {:ok, term()} | {:error, term()}

  # ---

  @callback delete_object(key :: String.t()) :: {:ok, term()} | {:error, term()}

  @callback copy_object(dest_key :: String.t(), src_key :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @callback copy_object(dest_bucket :: String.t(), dest_key :: String.t(), src_key :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @callback head_object(key :: String.t()) :: {:ok, term()} | {:error, term()}

  # ---

  @callback handle_conditions(action :: atom(), schema_or_struct :: any(), params :: map()) ::
              Keyword.t()

  @callback handle_ingest(key :: String.t()) :: {:ok, term()} | {:error, term()}

  @callback queue_ingest_upload(request_key :: String.t(), delay :: :none | integer()) ::
              {:ok, term()} | {:error, term()}

  @callback all_ingested_uploads(params :: map()) :: list()

  @callback all_pending_uploads(params :: map()) :: list()

  # ----

  @callback delete_schema_data(id_or_struct_or_params :: any()) ::
              {:ok, term()} | {:error, term()}

  @callback update_schema_data(id_or_struct :: any(), params :: map()) ::
              {:ok, term()} | {:error, term()}

  @callback find_schema_data(params :: map()) :: {:ok, term()} | {:error, term()}

  def bucket(endpoint), do: endpoint.bucket()

  def conditions(endpoint), do: endpoint.conditions()

  def schema(endpoint), do: endpoint.schema()

  def options(endpoint), do: endpoint.options()

  def handle_ingest(endpoint, request_key) do
    endpoint.handle_ingest(request_key)
  end

  def handle_conditions(endpoint, action, model, params) do
    endpoint.handle_conditions(action, model, params)
  end

  # Store API

  def delete_object(endpoint, key) do
    bucket = bucket(endpoint)
    opts = options(endpoint)

    Store.delete_object(bucket, key, opts)
  end

  def copy_object(endpoint, dest_key, src_key) do
    bucket = bucket(endpoint)
    opts = options(endpoint)

    Store.copy_object(bucket, dest_key, bucket, src_key, opts)
  end

  def copy_object(endpoint, dest_bucket, dest_key, src_key) do
    src_bucket = bucket(endpoint)
    opts = options(endpoint)

    Store.copy_object(dest_bucket, dest_key, src_bucket, src_key, opts)
  end

  def head_object(endpoint, key) do
    bucket = bucket(endpoint)
    opts = options(endpoint)

    Store.head_object(bucket, key, opts)
  end

  # Processing API

  def queue_ingest_upload(endpoint, %_{} = schema_data, delay) do
    schema = schema(endpoint)
    opts = options(endpoint)

    with {:ok, schema_data} <-
           Action.update_schema_data(schema, schema_data, %{processing: true}, opts),
         {:ok, job} <-
           Scheduler.queue_ingest_upload(
             %{endpoint: endpoint, key: schema_data.request_key},
             delay,
             opts
           ) do
      {:ok, %{schema_data: schema_data, job: job}}
    end
  end

  def queue_ingest_upload(endpoint, request_key, delay) do
    schema = schema(endpoint)
    opts = options(endpoint)

    with {:ok, schema_data} <- Action.find_schema_data(schema, %{request_key: request_key}, opts) do
      queue_ingest_upload(endpoint, schema_data, delay)
    end
  end

  def all_ingested_uploads(endpoint, params) do
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.all_ingested_uploads(schema, params, opts)
  end

  def all_pending_uploads(endpoint, params) do
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.all_pending_uploads(schema, params, opts)
  end

  # Action API

  def delete_schema_data(endpoint, id_or_struct_or_params) do
    schema = schema(endpoint)
    opts = options(endpoint)

    Action.delete_schema_data(schema, id_or_struct_or_params, opts)
  end

  def update_schema_data(endpoint, id_or_struct, params) do
    schema = schema(endpoint)
    opts = options(endpoint)

    Action.update_schema_data(schema, id_or_struct, params, opts)
  end

  def find_schema_data(endpoint, params \\ %{}) do
    schema = schema(endpoint)
    opts = options(endpoint)

    Action.find_schema_data(schema, params, opts)
  end

  # Upload API

  def complete_upload(endpoint, request_key, find_params, update_params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.complete_upload(bucket, schema, request_key, find_params, update_params, opts)
  end

  def abort_upload(endpoint, request_key, find_params, update_params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.abort_upload(bucket, schema, request_key, find_params, update_params, opts)
  end

  def pre_sign(endpoint, request_key, params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    conditions =
      endpoint
      |> handle_conditions(:pre_sign, schema, params)
      |> Keyword.take(@conditions_keys)

    if is_nil(conditions[:content_type]) do
      raise ArgumentError, "Condition :content_type is required"
    end

    if is_nil(conditions[:min_size]) or is_nil(conditions[:max_size]) do
      raise ArgumentError, "Conditions :min_size and :max_size are required"
    end

    opts = Keyword.merge(opts, conditions)

    Core.pre_sign(bucket, schema, request_key, params, opts)
  end

  def create_upload(endpoint, stored_key, request_key, filename, params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    conditions =
      endpoint
      |> handle_conditions(:create_upload, schema, params)
      |> Keyword.take(@conditions_keys)

    if is_nil(conditions[:content_type]) do
      raise ArgumentError, "Condition :content_type is required"
    end

    if is_nil(conditions[:min_size]) or is_nil(conditions[:max_size]) do
      raise ArgumentError, "Conditions :min_size and :max_size are required"
    end

    opts = Keyword.merge(opts, conditions)

    Core.create_upload(bucket, schema, stored_key, request_key, filename, params, opts)
  end

  def find_parts(endpoint, request_key, upload_id, params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.find_parts(bucket, schema, request_key, upload_id, params, opts)
  end

  def pre_sign_part(endpoint, request_key, upload_id, part_number, params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    conditions =
      endpoint
      |> handle_conditions(:pre_sign_part, schema, params)
      |> Keyword.take(@conditions_keys)

    if is_nil(conditions[:content_type]) do
      raise ArgumentError, "Condition :content_type is required"
    end

    opts = Keyword.merge(opts, conditions)

    opts =
      Keyword.update(
        opts,
        :headers,
        [{"Content-Type", conditions[:content_type]}],
        fn headers -> headers ++ [{"Content-Type", conditions[:content_type]}] end
      )

    Core.pre_sign_part(bucket, schema, request_key, upload_id, part_number, params, opts)
  end

  def complete_multipart_upload(
        endpoint,
        request_key,
        upload_id,
        parts,
        find_params,
        update_params
      ) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    conditions =
      endpoint
      |> handle_conditions(:complete_multipart_upload, schema, find_params)
      |> Keyword.take(@conditions_keys)

    if is_nil(conditions[:max_size]) do
      raise ArgumentError, "Condition :max_size is required"
    end

    opts = Keyword.merge(opts, conditions)

    Core.complete_multipart_upload(
      bucket,
      schema,
      request_key,
      upload_id,
      parts,
      find_params,
      update_params,
      opts
    )
  end

  def abort_multipart_upload(endpoint, request_key, upload_id, find_params, update_params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    Core.abort_multipart_upload(
      bucket,
      schema,
      request_key,
      upload_id,
      find_params,
      update_params,
      opts
    )
  end

  def create_multipart_upload(endpoint, stored_key, request_key, filename, params) do
    bucket = bucket(endpoint)
    schema = schema(endpoint)
    opts = options(endpoint)

    conditions =
      endpoint
      |> handle_conditions(:create_multipart_upload, schema, params)
      |> Keyword.take(@conditions_keys)

    if is_nil(conditions[:content_type]) do
      raise ArgumentError, "Condition :content_type is required"
    end

    if is_nil(conditions[:min_size]) or is_nil(conditions[:max_size]) do
      raise ArgumentError, "Conditions :min_size and :max_size are required"
    end

    opts = Keyword.merge(opts, conditions)

    Core.create_multipart_upload(
      bucket,
      schema,
      stored_key,
      request_key,
      filename,
      params,
      opts
    )
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.Endpoint

      @bucket Keyword.fetch!(opts, :bucket)
      @schema Keyword.fetch!(opts, :schema)
      @conditions Keyword.get(opts, :conditions, [])
      @options Keyword.get(opts, :options, [])

      @behaviour Uppy.Endpoint

      @impl true
      def bucket, do: @bucket

      @impl true
      def conditions, do: @conditions

      @impl true
      def schema, do: @schema

      @impl true
      def options, do: @options

      @impl true
      def delete_object(key) do
        Endpoint.delete_object(__MODULE__, key)
      end

      @impl true
      def copy_object(dest_key, src_key) do
        Endpoint.copy_object(__MODULE__, dest_key, src_key)
      end

      @impl true
      def copy_object(dest_bucket, dest_key, src_key) do
        Endpoint.copy_object(__MODULE__, dest_bucket, dest_key, src_key)
      end

      @impl true
      def head_object(key) do
        Endpoint.head_object(__MODULE__, key)
      end

      @impl true
      def delete_schema_data(id_or_struct) do
        Endpoint.delete_schema_data(__MODULE__, id_or_struct)
      end

      @impl true
      def update_schema_data(id_or_struct, params) do
        Endpoint.update_schema_data(__MODULE__, id_or_struct, params)
      end

      @impl true
      def find_schema_data(params \\ %{}) do
        Endpoint.find_schema_data(__MODULE__, params)
      end

      @impl true
      def queue_ingest_upload(request_key, delay \\ :none) do
        Endpoint.queue_ingest_upload(__MODULE__, request_key, delay)
      end

      @impl true
      def all_ingested_uploads(params) do
        Endpoint.all_ingested_uploads(__MODULE__, params)
      end

      @impl true
      def all_pending_uploads(params) do
        Endpoint.all_pending_uploads(__MODULE__, params)
      end

      @impl true
      def complete_upload(request_key, find_params \\ %{}, update_params \\ %{}) do
        Endpoint.complete_upload(__MODULE__, request_key, find_params, update_params)
      end

      @impl true
      def abort_upload(request_key, find_params \\ %{}, update_params \\ %{}) do
        Endpoint.abort_upload(__MODULE__, request_key, find_params, update_params)
      end

      @impl true
      def pre_sign(request_key, params \\ %{}) do
        Endpoint.pre_sign(__MODULE__, request_key, params)
      end

      @impl true
      def create_upload(stored_key, request_key, filename, params \\ %{}) do
        Endpoint.create_upload(__MODULE__, stored_key, request_key, filename, params)
      end

      @impl true
      def find_parts(request_key, upload_id, params \\ %{}) do
        Endpoint.find_parts(__MODULE__, request_key, upload_id, params)
      end

      @impl true
      def pre_sign_part(request_key, upload_id, part_number, params \\ %{}) do
        Endpoint.pre_sign_part(__MODULE__, request_key, upload_id, part_number, params)
      end

      @impl true
      def complete_multipart_upload(
            request_key,
            upload_id,
            parts,
            find_params \\ %{},
            update_params \\ %{}
          ) do
        Endpoint.complete_multipart_upload(
          __MODULE__,
          request_key,
          upload_id,
          parts,
          find_params,
          update_params
        )
      end

      @impl true
      def abort_multipart_upload(request_key, upload_id, find_params \\ %{}, update_params \\ %{}) do
        Endpoint.abort_multipart_upload(
          __MODULE__,
          request_key,
          upload_id,
          find_params,
          update_params
        )
      end

      @impl true
      def create_multipart_upload(stored_key, request_key, filename, params \\ %{}) do
        Endpoint.create_multipart_upload(__MODULE__, stored_key, request_key, filename, params)
      end
    end
  end
end
