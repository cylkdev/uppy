defmodule Uppy.Support.TestPipeline do
  def phases(opts \\ []) do
    [{Uppy.Support.Phases.CompleteUploadPhase, opts}]
  end
end
