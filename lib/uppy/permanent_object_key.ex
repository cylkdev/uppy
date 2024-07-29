defmodule Uppy.PermanentObjectKey do
  @moduledoc false
  alias Uppy.Config

  @default_permanent_object_key_adapter Uppy.PermanentObjectKeys.Default

  def validate(key, options \\ []) do
    adapter!(options).validate(key)
  end

  def prefix(id, resource_name, basename, options) do
    adapter!(options).prefix(id, resource_name, basename)
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
    Keyword.get(options, :permanent_object_key_adapter, Config.permanent_object_key_adapter()) ||
      @default_permanent_object_key_adapter
  end
end
