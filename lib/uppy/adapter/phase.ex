defmodule Uppy.Adapter.Phase do
  @callback run(input :: map(), options :: keyword()) :: term()
end
