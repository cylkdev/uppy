defmodule Uppy.Pipelines do
  def pipeline(adapter) do
    case adapter.pipeline() do
      phases when is_list(phases) -> phases
      term -> "Expected module `#{inspect(adapter)}` to return a list of phases, got: #{inspect(term, pretty: true)}"
    end
  end
end
