defmodule Uppy.Core.PostProcessingPipeline do

  alias Uppy.Phases.{
    HeadSchemaObjectMetadata,
    FileInfo,
    PutPermanentImageObjectCopy,
    PutPermanentObjectCopy,
    UpdateCompleteObjectMetadata
  }

  def phases(opts \\ []) do
    [
      {HeadSchemaObjectMetadata, opts},
      {FileInfo, opts},
      {PutPermanentImageObjectCopy, opts},
      {PutPermanentObjectCopy, opts},
      {UpdateCompleteObjectMetadata, opts}
    ]
  end
end
