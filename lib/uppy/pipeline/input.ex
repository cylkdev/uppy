defmodule Uppy.Pipeline.Input do
  @moduledoc false

  @enforce_keys [
    :bucket,
    :resource,
    :schema,
    :schema_data,
    :source
  ]

  defstruct @enforce_keys ++ [
    :holder,
    context: %{}
  ]
end
