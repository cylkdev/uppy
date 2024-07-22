defmodule Uppy.Actions do
  def create(adapter, schema, params, options) do
    adapter.create(schema, params, options)
  end

  def find(adapter, schema, params, options) do
    adapter.find(schema, params, options)
  end

  def update(adapter, schema, %_{} = schema_data, params, options) do
    adapter.update(schema, schema_data, params, options)
  end

  def update(adapter, schema, id, params, options) do
    adapter.update(schema, id, params, options)
  end

  def delete(adapter, schema, id, options) do
    adapter.delete(schema, id, options)
  end

  def delete(adapter, schema_data, options) do
    adapter.delete(schema_data, options)
  end

  def transaction(adapter, func, options) do
    adapter.transaction(func, options)
  end
end
