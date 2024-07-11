defmodule Uppy.Adapter.Thumbor do
  @callback put_result(String.t(), map(), String.t(), Keyword.t()) :: term()
end
