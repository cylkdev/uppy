defmodule Uppy.Support.TestPipeline.CompleteUploadPhase do
  @moduledoc false

  @behaviour Uppy.Phase

  @params %{
    content_length: 5,
    content_type: "image/jpeg",
    last_modified: ~U[2024-07-24 01:00:00Z]
  }

  def params, do: @params

  @impl Uppy.Phase
  def run(%{value: schema_data} = resolution, _opts \\ []) do
    schema_data = Map.merge(schema_data, @params)

    {:ok, %{resolution | value: schema_data}}
  end
end
