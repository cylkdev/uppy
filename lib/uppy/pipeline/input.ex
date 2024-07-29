defmodule Uppy.Pipeline.Input do
  @enforce_keys [
    :bucket,
    :resource_name,
    :schema,
    :schema_data,
    :source
  ]
  defstruct @enforce_keys ++
              [
                context: %{},
                holder: nil
              ]

  def create(attrs), do: struct!(__MODULE__, attrs)
end
