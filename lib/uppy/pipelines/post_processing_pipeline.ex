defmodule Uppy.Pipelines.PostProcessingPipeline do
  @moduledoc """
  ...
  """

  @behaviour Uppy.Pipeline

  @impl Uppy.Pipeline
  @doc """
  Returns the list of phases for processing completed file uploads.

  ### Examples

      iex> Uppy.Pipelines.PostProcessingPipeline.phases()
      [
        {Uppy.Phases.ValidateObjectTemporaryPath, []},
        {Uppy.Phases.HeadTemporaryObject, []},
        {Uppy.Phases.FileHolder, []},
        {Uppy.Phases.FileInfo, []},
        {Uppy.Phases.PutImageProcessorResult, []},
        {Uppy.Phases.PutPermanentObjectCopy, []},
        {Uppy.Phases.UpdateSchemaMetadata, []},
        {Uppy.Phases.ValidateObjectPermanentPath, []}
      ]
  """
  def phases(opts \\ []) do
    [
      {Uppy.Phases.ValidateObjectTemporaryPath, opts},
      {Uppy.Phases.HeadTemporaryObject, opts},
      {Uppy.Phases.FileHolder, opts},
      {Uppy.Phases.FileInfo, opts},
      {Uppy.Phases.PutImageProcessorResult, opts},
      {Uppy.Phases.PutPermanentObjectCopy, opts},
      {Uppy.Phases.UpdateSchemaMetadata, opts},
      {Uppy.Phases.ValidateObjectPermanentPath, opts}
    ]
  end
end
