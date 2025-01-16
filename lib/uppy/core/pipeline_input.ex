defmodule Uppy.Core.PipelineInput do
  @moduledoc false

  defstruct [
    :bucket,
    :query,
    :schema_data,
    :destination_object,
    state: :unresolved
  ]

  def new!(params), do: struct!(__MODULE__, params)
end
