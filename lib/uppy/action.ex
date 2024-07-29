defmodule Uppy.Action do
  @moduledoc """
  ...
  """
  alias Uppy.Config

  @default_action_adapter Uppy.EctoShortAction

  def create(schema, params, options) do
    adapter!(options).create(schema, params, options)
  end

  def find(schema, params, options) do
    adapter!(options).find(schema, params, options)
  end

  def update(schema, %_{} = schema_data, params, options) do
    adapter!(options).update(schema, schema_data, params, options)
  end

  def update(schema, id, params, options) do
    adapter!(options).update(schema, id, params, options)
  end

  def delete(schema, id, options) do
    adapter!(options).delete(schema, id, options)
  end

  def delete(schema_data, options) do
    adapter!(options).delete(schema_data, options)
  end

  def delete(schema_data) do
    delete(schema_data, [])
  end

  def transaction(func, options) do
    adapter!(options).transaction(func, options)
  end

  defp adapter!(options) do
    Keyword.get(options, :action_adapter, Config.action_adapter()) || @default_action_adapter
  end
end
