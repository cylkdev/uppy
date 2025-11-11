defmodule Uppy.Action do
  def delete_record(schema, id_or_struct, opts) do
    adapter(opts).delete(schema, id_or_struct, opts)
  end

  def update_record(schema, id_or_struct, params, opts) do
    adapter(opts).update(schema, id_or_struct, params, opts)
  end

  def find_record(schema, params, opts) do
    adapter(opts).find(schema, params, opts)
  end

  def create_record(schema, params, opts) do
    adapter(opts).create(schema, params, opts)
  end

  def all_records(schema, params, opts) do
    adapter(opts).all(schema, params, opts)
  end

  defp adapter(opts) do
    opts[:action][:adapter] || EctoShorts.Actions
  end
end
