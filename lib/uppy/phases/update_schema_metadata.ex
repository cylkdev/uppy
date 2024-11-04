defmodule Uppy.Phases.UpdateSchemaMetadata do
  @moduledoc """
  ...
  """
  alias Uppy.{DBAction, Resolution}

  @behaviour Uppy.Phase

  @impl true
  def run(
    %{
      state: :unresolved,
      context: context,
      query: query,
      value: schema_struct
    } = resolution,
    opts
  ) do
    content_type =
      if Map.has_key?(context, :file_info) do
        context.file_info.mimetype
      else
        context.metadata.content_type
      end

    with {:ok, schema_struct} <-
      DBAction.update(
        query,
        schema_struct,
        %{
          state: :completed,
          key: context.destination_object,
          e_tag: context.metadata.e_tag,
          content_type: content_type,
          content_length: context.metadata.content_length,
          last_modified: context.metadata.last_modified
        },
        opts
      ) do
      {:ok, Resolution.put_result(resolution, schema_struct)}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end
end
