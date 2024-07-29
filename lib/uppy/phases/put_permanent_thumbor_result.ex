defmodule Uppy.Phases.PutPermanentThumborResult do
  alias Uppy.{
    Config,
    PermanentObjectKey,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.Thumbor"

  @config Application.compile_env(Config.app(), __MODULE__, [])
  @default_adapter @config[:adapter] || Thumbor

  @default_resource_name "uploads"

  @default_max_image_size 1_024

  def run(
        %Uppy.Pipeline.Input{
          bucket: bucket,
          schema: schema,
          schema_data: schema_data,
          holder: holder,
          context: %{
            file_info: file_info
          } = context
        } = input,
        options
      ) do
    Utils.Logger.debug(@logger_prefix, "RUN BEGIN", binding: binding())

    if !completed?(context) and allowed?(file_info, options) do
      Utils.Logger.debug(@logger_prefix, "RUN destination object not found")

      with {:ok, destination_object} <-
        put_permanent_thumbor_result(bucket, holder, schema_data, options) do
        {:ok, %{input | context: Map.put(context, :destination_object, destination_object)}}
      end
    else
      Utils.Logger.debug(@logger_prefix, "RUN skipped")

      {:ok, input}
    end
  end

  defp completed?(%{destination_object: _}), do: true
  defp completed?(_), do: false

  defp allowed?(file_info, options) do
    image_info?(file_info) and resolution_in_bounds?(file_info, options)
  end

  defp resolution_in_bounds?(%{width: width, height: height}, options) do
    max_image_size = Keyword.get(options, :max_image_size, @default_max_image_size)

    (width <= max_image_size) and (height <= max_image_size)
  end

  defp image_info?(%{width: _, height: _}), do: true
  defp image_info?(_), do: false

  def put_permanent_thumbor_result(bucket, %_{} = holder, %_{} = schema_data, options) do
    Utils.Logger.debug(@logger_prefix, "PUT_PERMANENT_THUMBOR_RESULT BEGIN", binding: binding())

    holder_id = fetch_holder_id!(holder, options)
    resource_name = resource_name!(options)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key
    destination_object = PermanentObjectKey.prefix(holder_id, resource_name, basename, options)

    with {:ok, _} <-
      put_result(bucket, source_object, destination_object, options) do
      {:ok, destination_object}
    end
  end

  defp resource_name!(options) do
    with nil <- Keyword.get(options, :resource_name, @default_resource_name) do
      raise "option `:resource_name` cannot be `nil` for phase #{__MODULE__}"
    end
  end

  defp fetch_holder_id!(%_{} = holder, options) do
    source = holder_partition_source!(options)

    with nil <- Map.get(holder, source) do
      raise """
      The value of holder partition source #{inspect(source)} cannot be nil

      holder:
      #{inspect(holder, pretty: true)}
      """
    end
  end

  defp holder_partition_source!(options) do
    with nil <- Keyword.get(options, :holder_partition_source, :organization) do
      raise "option `:holder_partition_source` cannot be `nil` for phase #{__MODULE__}"
    end
  end

  defp thumbor_adapter!(options) do
    Keyword.get(options, :thumbor_adapter, @default_adapter)
  end

  def put_result(bucket, source_object, destination_object, options) do
    params = options[:pipeline][:thumbor][:parameters] || %{}

    thumbor_adapter!(options).put_result(
      bucket,
      source_object,
      params,
      destination_object,
      options
    )
  end
end
