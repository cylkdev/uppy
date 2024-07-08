defmodule Uppy.PermanentScopes do
  def path?(adapter, path, partition_id, resource_name) do
    adapter.path?(path, partition_id, resource_name)
  end

  def prefix(adapter, resource_name, partition_id, basename) do
    adapter.prefix(resource_name, partition_id, basename)
  end
end
