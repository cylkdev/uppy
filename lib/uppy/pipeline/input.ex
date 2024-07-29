defmodule Uppy.Pipeline.Input do
  defstruct [
    :bucket,
    :resource_name,
    :options,
    :schema,
    :source,
    :value
  ]

  def create(attrs), do: struct!(__MODULE__, attrs)
end
