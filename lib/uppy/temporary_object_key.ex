defmodule Uppy.TemporaryObjectKey do
  @moduledoc false
  alias Uppy.Config

  @default_temporary_object_key_adapter Uppy.TemporaryObjectKeys.Default

  def validate(key, options \\ []) do
    adapter!(options).validate(key)
  end

  def prefix(id, basename, options) do
    adapter!(options).prefix(id, basename)
  end

  def prefix(id, options) do
    adapter!(options).prefix(id)
  end

  def prefix(options) do
    adapter!(options).prefix()
  end

  defp adapter!(options) do
    Keyword.get(options, :temporary_object_key_adapter, Config.temporary_object_key_adapter()) ||
      @default_temporary_object_key_adapter
  end
end
