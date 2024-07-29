defmodule Uppy.Phases.PutPermanentObjectCopy do
  @moduledoc """
  Copies the object to permanent object path.
  """
  alias Uppy.{
    Storage,
    PermanentObjectKey,
    TemporaryObjectKey,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.PutPermanentObjectCopy"

  @default_resource_name "uploads"

  @impl Uppy.Adapter.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipeline.Input{
          bucket: bucket,
          schema: schema,
          value: %{
            holder: holder,
            schema_data: schema_data
          },
          options: runtime_options
        } = _input,
        phase_options
      ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN", binding: binding())

    options = Keyword.merge(phase_options, runtime_options)

    put_permanent_object_copy(bucket, holder, schema_data, options)
  end

  def put_permanent_object_copy(bucket, %_{} = holder, %_{} = schema_data, options) do
    Utils.Logger.debug(@logger_prefix, "put_permanent_object_copy BEGIN", binding: binding())

    holder_id = fetch_holder_id!(holder, options)
    resource_name = resource_name!(options)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key
    destination_object = PermanentObjectKey.prefix(holder_id, resource_name, basename, options)

    with {:ok, _} <- TemporaryObjectKey.validate(source_object, options) do
      Storage.put_object_copy(
        bucket,
        destination_object,
        bucket,
        source_object,
        options
      )
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
end
