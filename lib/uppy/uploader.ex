defmodule Uppy.Uploader do
  @moduledoc """
  ...
  """

  alias Uppy.{Core, DBAction}

  alias Uppy.Uploader.{
    Route,
    Scheduler
  }

  @available :available
  @cancelled :cancelled
  @pending :pending

  @doc """
  ...
  """
  @callback bucket :: binary()

  @doc """
  ...
  """
  @callback query :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}

  @doc """
  ...
  """
  @callback resource_name :: binary()

  @doc """
  ...
  """
  @callback pipeline :: module()

  @doc """
  ...
  """
  @callback find_parts(
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              next_part_number_marker :: term() | nil,
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback presigned_part(
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              part_number :: integer(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback complete_multipart_upload(
              route_params :: map(),
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              update_params :: map(),
              parts :: list(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback abort_multipart_upload(
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback start_multipart_upload(
              route_params :: map(),
              create_params :: map()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback move_upload(
              destination_object :: binary(),
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              pipeline :: module(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback process_upload(
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              pipeline :: module(),
              context :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback complete_upload(
              route_params :: map(),
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback abort_upload(
              find_params_or_schema_data :: map() | Ecto.Schema.t(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback start_upload(
              route_params :: term(),
              create_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @unique_identifier_byte_size 4

  @doc """
  ...
  """
  def find_parts(bucket, query, find_params_or_schema_data, next_part_number_marker, opts) do
    with {:ok, res} <-
           Core.find_parts(
             bucket,
             query,
             find_params_or_schema_data,
             next_part_number_marker,
             opts
           ) do
      {:ok,
       %{
         parts: res.parts,
         schema_data: res.schema_data
       }}
    end
  end

  @doc """
  ...
  """
  def presigned_part(bucket, query, find_params_or_schema_data, part_number, opts) do
    with {:ok, res} <-
           Core.presigned_part(bucket, query, find_params_or_schema_data, part_number, opts) do
      {:ok,
       %{
         presigned_part: res.presigned_part,
         schema_data: res.schema_data
       }}
    end
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
        bucket,
        route_params,
        query,
        find_params_or_schema_data,
        update_params,
        parts,
        opts
      ) do
    update_params =
      Map.merge(
        %{
          status: @available,
          unique_identifier: generate_unique_identifier(opts)
        },
        update_params
      )

    with {:ok, %{metadata: metadata, schema_data: schema_data}} <-
           Core.complete_multipart_upload(
             bucket,
             query,
             find_params_or_schema_data,
             update_params,
             parts,
             opts
           ),
         destination_object <-
           build_permanent_key(
             route_params,
             schema_data.unique_identifier,
             schema_data.filename,
             opts
           ),
         {:ok, job} <-
           Scheduler.queue_move_upload(
             bucket,
             destination_object,
             query,
             schema_data.id,
             opts[:pipeline] || Uppy.Pipelines.PostProcessingPipeline,
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data,
         destination: destination_object,
         jobs: %{move_upload: job}
       }}
    end
  end

  @doc """
  ...
  """
  def abort_multipart_upload(bucket, query, find_params_or_schema_data, update_params, opts) do
    with {:ok, res} <-
           Core.abort_multipart_upload(
             bucket,
             query,
             find_params_or_schema_data,
             Map.put_new(update_params, :status, @cancelled),
             opts
           ) do
      {:ok,
       %{
         metadata: res.metadata,
         schema_data: res.schema_data
       }}
    end
  end

  @doc """
  ...
  """
  def start_multipart_upload(bucket, route_params, query, create_params, opts) do
    with create_params <- prepare_create_params(route_params, create_params, opts),
         {:ok, res} <- Core.start_multipart_upload(bucket, query, create_params, opts),
         {:ok, job} <-
           Scheduler.queue_abort_multipart_upload(
             bucket,
             query,
             res.schema_data.id,
             opts
           ) do
      {:ok,
       %{
         multipart_upload: res.multipart_upload,
         schema_data: res.schema_data,
         jobs: %{abort_multipart_upload: job}
       }}
    end
  end

  @doc """
  ...
  """
  def move_upload(bucket, destination_object, query, %_{} = schema_data, pipeline, opts) do
    process_upload(
      bucket,
      query,
      schema_data,
      pipeline,
      %{destination_object: destination_object},
      opts
    )
  end

  def move_upload(bucket, destination_object, query, find_params, pipeline, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      move_upload(bucket, destination_object, query, schema_data, pipeline, opts)
    end
  end

  @doc """
  ...
  """
  def process_upload(bucket, query, find_params_or_schema_data, pipeline, context, opts) do
    with {:ok, res} <-
           Core.process_upload(
             bucket,
             query,
             find_params_or_schema_data,
             pipeline,
             context,
             opts
           ) do
      {:ok,
       %{
         resolution: res.resolution,
         done: res.done
       }}
    end
  end

  @doc """
  ...
  """
  def complete_upload(
        bucket,
        route_params,
        query,
        find_params_or_schema_data,
        update_params,
        opts
      ) do
    update_params =
      Map.merge(
        %{
          status: @available,
          unique_identifier: generate_unique_identifier(opts)
        },
        update_params
      )

    with {:ok, %{metadata: metadata, schema_data: schema_data}} <-
           Core.confirm_upload(
             bucket,
             query,
             find_params_or_schema_data,
             update_params,
             opts
           ),
         destination_object <-
           build_permanent_key(
             route_params,
             schema_data.unique_identifier,
             schema_data.filename,
             opts
           ),
         {:ok, job} <-
           Scheduler.queue_move_upload(
             bucket,
             destination_object,
             query,
             schema_data.id,
             opts[:pipeline] || Uppy.Pipelines.PostProcessingPipeline,
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data,
         destination: destination_object,
         jobs: %{move_upload: job}
       }}
    end
  end

  @doc """
  ...
  """
  def abort_upload(bucket, query, find_params_or_schema_data, update_params, opts) do
    with {:ok, res} <-
           Core.abort_upload(
             bucket,
             query,
             find_params_or_schema_data,
             Map.put_new(update_params, :status, @cancelled),
             opts
           ) do
      {:ok, %{schema_data: res.schema_data}}
    end
  end

  @doc """
  ...
  """
  def start_upload(bucket, route_params, query, create_params, opts) do
    with create_params <- prepare_create_params(route_params, create_params, opts),
         {:ok, res} <- Core.start_upload(bucket, query, create_params, opts),
         {:ok, job} <-
           Scheduler.queue_abort_upload(
             bucket,
             query,
             res.schema_data.id,
             opts
           ) do
      {:ok,
       %{
         presigned_upload: res.presigned_upload,
         schema_data: res.schema_data,
         jobs: %{abort_upload: job}
       }}
    end
  end

  defp prepare_create_params(route_params, create_params, opts) do
    filename = create_params.filename

    unique_identifier =
      if Map.has_key?(create_params, :unique_identifier) do
        create_params.unique_identifier
      else
        create_params[:timestamp] || :os.system_time() |> to_string() |> String.reverse()
      end

    key = build_temporary_key(route_params, unique_identifier, filename, opts)

    create_params
    |> Map.delete(:timestamp)
    |> Map.merge(%{
      status: @pending,
      filename: filename,
      key: key
    })
  end

  defp build_permanent_key(route_params, unique_identifier, filename, opts) do
    opts
    |> permanent_route!()
    |> Route.path("#{unique_identifier}-#{filename}", route_params)
  end

  defp build_temporary_key(route_params, unique_identifier, filename, opts) do
    opts
    |> temporary_route!()
    |> Route.path("#{unique_identifier}-#{filename}", route_params)
  end

  defp permanent_route!(opts) do
    opts[:permanent_route_adapter] || Uppy.Uploader.Routes.PermanentRoute
  end

  defp temporary_route!(opts) do
    opts[:temporary_route_adapter] || Uppy.Uploader.Routes.TemporaryRoute
  end

  defp generate_unique_identifier(opts) do
    byte_size = opts[:unique_identifier_byte_size] || @unique_identifier_byte_size
    bytes = :crypto.strong_rand_bytes(byte_size)

    encoding = opts[:base_encode] || :encode32
    encoding_opts = opts[:base_encode_options] || [padding: false]

    apply(Base, encoding, [bytes, encoding_opts])
  end

  defmacro __using__(opts) do
    quote do
      opts = Uppy.Uploader.Definition.validate!(unquote(opts))

      @moduledoc """
      Uppy.Uploader

      ### Options

      #{NimbleOptions.docs(Uppy.Uploader.Definition.definition())}
      """

      @behaviour Uppy.Uploader

      @bucket opts[:bucket]
      @resource_name opts[:resource_name]
      @query opts[:query]
      @pipeline opts[:pipeline]

      @doc "See c:Uppy.Uploader.bucket/0"
      @impl true
      def bucket, do: @bucket

      @doc "See c:Uppy.Uploader.query/0"
      @impl true
      def query, do: @query

      @doc "See c:Uppy.Uploader.resource_name/0"
      @impl true
      def resource_name, do: @resource_name

      @doc "See c:Uppy.Uploader.pipeline/0"
      @impl true
      def pipeline, do: @pipeline

      @doc "See c:Uppy.Uploader.find_parts/3"
      @impl true
      def find_parts(find_params_or_schema_data, next_part_number_marker \\ nil, opts \\ []) do
        Uppy.Uploader.find_parts(
          @bucket,
          @query,
          find_params_or_schema_data,
          next_part_number_marker,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.presigned_part/3"
      @impl true
      def presigned_part(find_params_or_schema_data, part_number, opts \\ []) do
        Uppy.Uploader.presigned_part(
          @bucket,
          @query,
          find_params_or_schema_data,
          part_number,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.complete_multipart_upload/5"
      @impl true
      def complete_multipart_upload(
            route_params,
            find_params_or_schema_data,
            update_params,
            parts,
            opts \\ []
          ) do
        Uppy.Uploader.complete_multipart_upload(
          @bucket,
          route_params,
          @query,
          find_params_or_schema_data,
          update_params,
          parts,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.abort_multipart_upload/3"
      @impl true
      def abort_multipart_upload(find_params_or_schema_data, update_params, opts \\ []) do
        Uppy.Uploader.abort_multipart_upload(
          @bucket,
          @query,
          find_params_or_schema_data,
          update_params,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.start_multipart_upload/3"
      @impl true
      def start_multipart_upload(route_params, create_params, opts \\ []) do
        Uppy.Uploader.start_multipart_upload(
          @bucket,
          route_params,
          @query,
          create_params,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.move_upload/4"
      @impl true
      def move_upload(
            destination_object,
            find_params_or_schema_data,
            pipeline \\ @pipeline,
            opts \\ []
          ) do
        Uppy.Uploader.move_upload(
          @bucket,
          destination_object,
          @query,
          find_params_or_schema_data,
          pipeline,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.process_upload/4"
      @impl true
      def process_upload(find_params_or_schema_data, pipeline \\ @pipeline, context, opts \\ []) do
        Uppy.Uploader.process_upload(
          @bucket,
          @query,
          find_params_or_schema_data,
          pipeline,
          context,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.complete_upload/4"
      @impl true
      def complete_upload(route_params, find_params_or_schema_data, update_params, opts \\ []) do
        Uppy.Uploader.complete_upload(
          @bucket,
          route_params,
          @query,
          find_params_or_schema_data,
          update_params,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.abort_upload/3"
      @impl true
      def abort_upload(find_params_or_schema_data, update_params, opts \\ []) do
        Uppy.Uploader.abort_upload(
          @bucket,
          @query,
          find_params_or_schema_data,
          update_params,
          opts
        )
      end

      @doc "See c:Uppy.Uploader.start_upload/3"
      @impl true
      def start_upload(route_params, create_params, opts \\ []) do
        Uppy.Uploader.start_upload(
          @bucket,
          route_params,
          @query,
          create_params,
          opts
        )
      end
    end
  end
end
