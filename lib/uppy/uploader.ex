defmodule Uppy.Uploader do
  @moduledoc """
  ...
  """

  alias Uppy.{
    Core,
    DBAction,
    Route,
    Scheduler
  }

  @available :available
  @cancelled :cancelled
  @pending :pending

  @unique_identifier_byte_size 4

  @doc """
  ...
  """
  def find_parts(bucket, query, find_params_or_schema_data, opts) do
    with {:ok, res} <-
           Core.find_parts(
             bucket,
             query,
             find_params_or_schema_data,
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
             opts[:pipeline] || Uppy.Pipelines.TransferPipeline,
             opts
           ) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data,
         destination: destination_object,
         jobs: %{
           move_upload: job
         }
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
  def move_upload(bucket, destination_object, query, %_{} = schema_data, opts) do
    process_upload(
      bucket,
      query,
      schema_data,
      opts[:pipeline] || Uppy.Pipelines.TransferPipeline,
      %{destination_object: destination_object},
      Keyword.delete(opts, :pipeline)
    )
  end

  def move_upload(bucket, destination_object, query, find_params, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      move_upload(bucket, destination_object, query, schema_data, opts)
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
      {:ok, %{
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
             opts[:pipeline] || Uppy.Pipelines.TransferPipeline,
             opts
           ) do
      {:ok, %{
        metadata: metadata,
        schema_data: schema_data,
        destination: destination_object,
        jobs: %{
          move_upload: job
        }
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
    opts[:permanent_route_adapter] || Uppy.Routes.PermanentRoute
  end

  defp temporary_route!(opts) do
    opts[:temporary_route_adapter] || Uppy.Routes.TemporaryRoute
  end

  defp generate_unique_identifier(opts) do
    byte_size = opts[:unique_identifier_byte_size] || @unique_identifier_byte_size
    bytes = :crypto.strong_rand_bytes(byte_size)

    encoding = opts[:base_encode] || :encode32
    encoding_opts = opts[:base_encode_options] || [padding: false]

    apply(Base, encoding, [bytes, encoding_opts])
  end
end
