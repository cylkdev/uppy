defmodule Uppy.Adapter.PermanentScope do
  @type adapter :: module()

  @callback path?(binary()) :: boolean()

  @callback prefix(binary(), binary(), binary()) :: binary()
end
