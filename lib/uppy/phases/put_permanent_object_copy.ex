defmodule Uppy.Phases.PutPermanentObjectCopy do
  @moduledoc """
  Copies the object to permanent object path.
  """
  alias Uppy.{
    PathBuilder,
    Storage,
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

  @default_resource "uploads"

  @impl Uppy.Adapter.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
    %Uppy.Pipeline.Input{
      bucket: bucket,
      schema: schema,
      schema_data: schema_data,
      holder: holder,
      context: context
    } = input,
    options
  ) do
    Utils.Logger.debug(@logger_prefix, "RUN BEGIN", binding: binding())

    if !completed?(context) do
      Utils.Logger.debug(@logger_prefix, "RUN destination object not found")

      with {:ok, destination_object} <-
        put_permanent_object_copy(bucket, holder, schema_data, options) do
        {:ok, %{input | context: Map.put(context, :destination_object, destination_object)}}
      end
    else
      Utils.Logger.debug(@logger_prefix, "RUN skipped")

      {:ok, input}
    end
  end

  defp completed?(%{destination_object: _}), do: true
  defp completed?(_), do: false

  def put_permanent_object_copy(bucket, %_{} = holder, %_{} = schema_data, options) do
    Utils.Logger.debug(@logger_prefix, "PUT_PERMANENT_OBJECT_COPY BEGIN", binding: binding())

    holder_id = fetch_holder_id!(holder, options)
    resource = resource!(options)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key

    destination_object =
      PathBuilder.permanent_path(
        %{
          id: holder_id,
          resource: resource,
          basename: basename
        },
        options
      )

    with :ok <- PathBuilder.validate_temporary_path(source_object, options),
      {:ok, _} <-
        Storage.put_object_copy(
          bucket,
          destination_object,
          bucket,
          source_object,
          options
        ) do
      {:ok, destination_object}
    end
  end

  defp resource!(options) do
    with nil <- Keyword.get(options, :resource, @default_resource) do
      raise "option `:resource` cannot be `nil` for phase #{__MODULE__}"
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
