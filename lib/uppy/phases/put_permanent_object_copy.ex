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

  @impl true
  @doc """
  Implementation for `c:Uppy.Phase.run/2`
  """
  @spec run(resolution(), opts()) :: t_res(resolution())
  def run(
    %{
      state: :unresolved,
      bucket: bucket,
      context: context,
      value: schema_struct,
    } = resolution,
    opts
  ) do
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

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end
end
