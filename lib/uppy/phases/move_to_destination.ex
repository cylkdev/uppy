defmodule Uppy.Phases.MoveToDestination do
  @moduledoc false
  alias Uppy.{DBAction, Storage}

  @behaviour Uppy.Phase

  @impl true
  def run(
        %{
          state: :unresolved,
          bucket: bucket,
          query: query,
          value: schema_data,
          arguments: args
        } = input,
        opts
      ) do
    src_object = schema_data.key
    dest_object = args.destination_object

    with {:ok, metadata} <- Storage.head_object(bucket, src_object, opts),
         {:ok, _} <-
           Storage.put_object_copy(
             bucket,
             dest_object,
             bucket,
             src_object,
             opts
           ),
         {:ok, schema_data} <-
           DBAction.update(
             query,
             schema_data,
             %{
               state: :ready,
               key: dest_object,
               e_tag: metadata.e_tag,
               content_length: metadata.content_length,
               last_modified: metadata.last_modified
             },
             opts
           ),
         {:ok, _} <- Storage.delete_object(bucket, src_object, opts) do
      {:ok, %{input | value: schema_data}}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end
end
