defmodule Uppy.Phases.PutPermanentObjectCopy do
  @moduledoc """
  Copies the object to permanent object path.
  """
  alias Uppy.{
    PathBuilder,
    Storage,
    Utils
  }

  @type resolution :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type opts :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.PutPermanentObjectCopy"

  @default_resource "uploads"

  @impl Uppy.Phase
  @doc """
  Implementation for `c:Uppy.Phase.run/2`
  """
  @spec run(resolution(), opts()) :: t_res(resolution())
  def run(
    %Uppy.Resolution{
      bucket: bucket,
      value: schema_data,
      context: context
    } = resolution,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    holder = context.holder

    if phase_completed?(context) do
      Utils.Logger.debug(@logger_prefix, "run - skipping execution")

      {:ok, resolution}
    else
      Utils.Logger.debug(@logger_prefix, "run - copying image")

      with {:ok, destination_object} <-
        put_permanent_object_copy(bucket, holder, schema_data, opts) do
        Utils.Logger.debug(@logger_prefix, "run - copied image to #{inspect(destination_object)}")

        {:ok, %{resolution | context: Map.put(context, :destination_object, destination_object)}}
      end
    end
  end

  defp phase_completed?(%{destination_object: _}), do: true
  defp phase_completed?(_), do: false

  def put_permanent_object_copy(bucket, %_{} = holder, %_{} = schema_data, opts) do
    holder_id = Uppy.Holder.fetch_id!(holder, opts)
    resource = resource!(opts)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key

    destination_object =
      PathBuilder.permanent_path(
        %{
          id: holder_id,
          resource: resource,
          basename: basename
        },
        opts
      )

    with :ok <- PathBuilder.validate_temporary_path(source_object, opts),
      {:ok, _} <-
        Storage.put_object_copy(
          bucket,
          destination_object,
          bucket,
          source_object,
          opts
        ) do
      {:ok, destination_object}
    end
  end

  defp resource!(opts) do
    with nil <- Keyword.get(opts, :resource, @default_resource) do
      raise "option `:resource` cannot be `nil` for phase #{__MODULE__}"
    end
  end
end
