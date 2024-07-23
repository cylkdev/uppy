defmodule Uppy.Pipelines.Phases do
  def run(phase, input, options) do
    phase.run(input, options)
  end
end
