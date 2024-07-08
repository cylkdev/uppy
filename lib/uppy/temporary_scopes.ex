defmodule Uppy.TemporaryScopes do
  def path?(adapter, path) do
    adapter.path?(path)
  end

  def prefix(adapter, id, partition) do
    adapter.prefix(id, partition)
  end
end
