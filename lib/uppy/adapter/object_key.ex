defmodule Uppy.Adapter.ObjectKey do
  @type adapter :: module()

  @callback path?(attrs :: Keyword.t()) :: boolean()
  @callback build(attrs :: Keyword.t()) :: String.t()
end
