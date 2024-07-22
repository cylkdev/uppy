defmodule Uppy.PermanentObjectKeys do
  @moduledoc false

  def validate_path(adapter, key), do: adapter.validate_path(key)

  def encode_id(adapter, id), do: adapter.encode_id(id)

  def decode_id(adapter, encoded_id), do: adapter.decode_id(encoded_id)

  def prefix(adapter, id, resource_name, basename), do: adapter.prefix(id, resource_name, basename)

  def prefix(adapter, id, basename), do: adapter.prefix(id, basename)

  def prefix(adapter, id), do: adapter.prefix(id)

  def prefix(adapter), do: adapter.prefix()
end
