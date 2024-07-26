defmodule Uppy.TemporaryObjectKeys do
  @moduledoc false
  alias Uppy.Config

  @default_temporary_object_key_adapter Uppy.Adapters.TemporaryObjectKey

  def validate(key, options \\ []) do
    temporary_object_key_adapter!(options).validate(key)
  end

  def encode_id(id, options) do
    temporary_object_key_adapter!(options).encode_id(id)
  end

  def decode_id(encoded_id, options) do
    temporary_object_key_adapter!(options).decode_id(encoded_id)
  end

  def prefix(id, basename, options) do
    temporary_object_key_adapter!(options).prefix(id, basename)
  end

  def prefix(id, options) do
    temporary_object_key_adapter!(options).prefix(id)
  end

  def prefix(options) do
    temporary_object_key_adapter!(options).prefix()
  end

  defp temporary_object_key_adapter!(options) do
    Keyword.get(options, :temporary_object_key_adapter, Config.temporary_object_key_adapter()) ||
      @default_temporary_object_key_adapter
  end
end
