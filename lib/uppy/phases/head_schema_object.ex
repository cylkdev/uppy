defmodule Uppy.Phases.HeadSchemaObject do
  @moduledoc """
  ...
  """
  alias Uppy.{Resolution, Storage}

  @behaviour Uppy.Phase

  @impl true
  def run(
    %{
      state: :unresolved,
      bucket: bucket,
      value: schema_struct
    } = resolution,
    opts
  ) do
    with {:ok, metadata} <- Storage.head_object(bucket, schema_struct.key, opts) do
      {:ok, Resolution.assign_context(resolution, :metadata, metadata)}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end
end
