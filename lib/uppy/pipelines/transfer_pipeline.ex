defmodule Uppy.Pipelines.TransferPipeline do
  @moduledoc """
  ...
  """

  alias Uppy.Phases.{
    # FileInfo,
    HeadSchemaObject,
    # PutPermanentImageObjectCopy,
    PutPermanentObjectCopy,
    UpdateSchemaMetadata
  }

  def phases(opts) do
    [
      {HeadSchemaObject, opts},
      # {FileInfo, opts},
      # {PutPermanentImageObjectCopy, opts},
      {PutPermanentObjectCopy, opts},
      {UpdateSchemaMetadata, opts}
    ]
  end
end
