defmodule Uppy.Phases.PutPermanentObjectCopy do
  @moduledoc """
  Copies the object to permanent object path.
  """
  alias Uppy.{
    Resolution,
    Storage
  }

  @type resolution :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_struct :: Ecto.Schema.t()
  @type params :: map()
  @type opts :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.PutPermanentObjectCopy"

  @impl true
  def phase_completed?(resolution) do
    case Resolution.get_private(resolution, __MODULE__) do
      %{completed: true} ->
        Uppy.Utils.Logger.debug(@logger_prefix, "Phase completed.")

        true

      _ ->
        Uppy.Utils.Logger.debug(@logger_prefix, "Phase not complete.")

        false

    end
  end

  @impl true
  @doc """
  Implementation for `c:Uppy.Phase.run/2`
  """
  @spec run(resolution(), opts()) :: t_res(resolution())
  def run(
    %{
      bucket: bucket,
      context: context,
      value: schema_struct,
    } = resolution,
    opts
  ) do
    if phase_completed?(resolution) do
      {:ok, resolution}
    else
      with {:ok, response} <-
        Storage.put_object_copy(
          bucket,
          context.destination_object,
          bucket,
          schema_struct.key,
          opts
        ) do
        {:ok, Resolution.put_private(resolution, __MODULE__, %{
          storage: response
        })}
      end
    end
  end
end
