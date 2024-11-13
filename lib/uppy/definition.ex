defmodule Uppy.Definition do
  @moduledoc """
  ...
  """

  @definition [
    bucket: [
      doc: "Name of the storage bucket",
      type: :string,
      required: true
    ],
    query: [
      doc: "The query argument to pass to the database action adapter.",
      type: :any,
      required: true
    ],
    resource_name: [
      doc: "Permanent resource name",
      type: :string,
      required: true
    ],
    pipeline: [
      doc: "The pipeline module.",
      type: :atom,
      required: true,
      default: Uppy.Pipelines.PostProcessingPipeline
    ]
  ]

  def definition, do: @definition

  @doc false
  def validate!(opts) do
    NimbleOptions.validate!(opts, @definition)
  end
end
