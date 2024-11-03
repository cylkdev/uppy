defmodule Uppy.Phases.HeadSchemaObjectMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{Resolution, Storage}

  @behaviour Uppy.Phase

  @impl true
  def phase_completed?(_), do: false

  @impl true
  def run(
    %{
      bucket: bucket,
      value: schema_struct
    } = resolution,
    opts
  ) do
    with {:ok, metadata} <- Storage.head_object(bucket, schema_struct.key, opts) do
      {:ok, Resolution.assign_context(resolution, :metadata, metadata)}
    end
  end
end
