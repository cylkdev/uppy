defmodule Uppy.Pipelines.Input do
  defstruct [
    :bucket,
    :resource_name,
    :schema,
    :source,
    :schema_data,
    :context,
    :options
  ]
end
