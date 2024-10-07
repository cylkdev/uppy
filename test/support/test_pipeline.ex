defmodule Uppy.Support.TestPipeline do
  def phases(opts \\ []) do
    [{Uppy.Support.TestPipeline.CompleteUploadPhase, opts}]
  end
end
