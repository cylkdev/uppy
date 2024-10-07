defmodule Uppy.Action do
  @moduledoc """
  ...
  """
  alias Uppy.Config

  @default_action_adapter Uppy.Actions.EctoAction

  def create(schema, params, opts \\ []) do
    adapter!(opts).create(schema, params, opts)
  end

  def find(schema, params, opts \\ []) do
    adapter!(opts).find(schema, params, opts)
  end

  def update(schema, id_or_schema_data, params, opts \\ [])

  def update(schema, %_{} = schema_data, params, opts) do
    adapter!(opts).update(schema, schema_data, params, opts)
  end

  def update(schema, id, params, opts) do
    adapter!(opts).update(schema, id, params, opts)
  end

  def delete(schema, id, opts) do
    adapter!(opts).delete(schema, id, opts)
  end

  def delete(schema_data, opts) do
    adapter!(opts).delete(schema_data, opts)
  end

  def delete(schema_data) do
    delete(schema_data, [])
  end

  def transaction(func, opts \\ []) do
    adapter!(opts).transaction(func, opts)
  end

  defp adapter!(opts) do
    with nil <- opts[:action_adapter],
      nil <- Config.action_adapter() do
      @default_action_adapter
    end
  end
end
