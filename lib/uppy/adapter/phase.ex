defmodule Uppy.Adapter.Phase do
  @callback run(input :: map(), opts :: keyword()) :: term()
end
