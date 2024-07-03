defmodule Uppy.ObjectKey do
  @type adapter :: Uppy.Adapter.ObjectKey.adapter()

  @spec path?(adapter :: adapter(), term()) :: boolean()
  def path?(adapter, attrs) do
    adapter.path?(attrs)
  end

  @spec build(adapter :: adapter(), term()) :: String.t()
  def build(adapter, attrs) do
    adapter.build(attrs)
  end
end
