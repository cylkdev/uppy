defmodule Uppy.Adapter.TemporaryScope do
  @type adapter :: module()

  @callback path?(binary()) :: boolean()

  @callback prefix(binary(), binary()) :: binary()
end
