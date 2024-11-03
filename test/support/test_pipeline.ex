defmodule Uppy.TestPipeline do
  def phases(opts) do
    [{Uppy.Phases.CompleteUploadPhase, opts}]
  end
end
