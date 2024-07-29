defmodule Uppy.PermanentObjectKey do
  @moduledoc false
  alias Uppy.Config

  @default_permanent_object_key_adapter Uppy.Adapters.PermanentObjectKey

  def validate(key, options \\ []) do
    permanent_object_key_adapter!(options).validate(key)
  end

  def encode_id(id, options) do
    permanent_object_key_adapter!(options).encode_id(id)
  end

  def decode_id(encoded_id, options) do
    permanent_object_key_adapter!(options).decode_id(encoded_id)
  end

  def prefix(id, resource_name, basename, options) do
    permanent_object_key_adapter!(options).prefix(id, resource_name, basename)
  end

  def prefix(id, basename, options) do
    permanent_object_key_adapter!(options).prefix(id, basename)
  end

  def prefix(id, options) do
    permanent_object_key_adapter!(options).prefix(id)
  end

  def prefix(options) do
    permanent_object_key_adapter!(options).prefix()
  end

  defp permanent_object_key_adapter!(options) do
    Keyword.get(options, :permanent_object_key_adapter, Config.permanent_object_key_adapter()) ||
      @default_permanent_object_key_adapter
  end
end
