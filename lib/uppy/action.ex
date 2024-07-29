defmodule Uppy.Action do
  @moduledoc """
  ...
  """
  alias Uppy.Config

  @default_actions_adapter Uppy.EctoShortAction

  def create(schema, params, options) do
    actions_adapter!(options).create(schema, params, options)
  end

  def find(schema, params, options) do
    actions_adapter!(options).find(schema, params, options)
  end

  def update(schema, %_{} = schema_data, params, options) do
    actions_adapter!(options).update(schema, schema_data, params, options)
  end

  def update(schema, id, params, options) do
    actions_adapter!(options).update(schema, id, params, options)
  end

  def delete(schema, id, options) do
    actions_adapter!(options).delete(schema, id, options)
  end

  def delete(schema_data, options) do
    actions_adapter!(options).delete(schema_data, options)
  end

  def delete(schema_data) do
    delete(schema_data, [])
  end

  def transaction(func, options) do
    actions_adapter!(options).transaction(func, options)
  end

  defp actions_adapter!(options) do
    Keyword.get(options, :actions_adapter, Config.actions_adapter()) || @default_actions_adapter
  end
end
