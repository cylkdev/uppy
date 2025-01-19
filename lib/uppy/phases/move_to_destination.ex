defmodule Uppy.Phases.MoveToDestination do
  @moduledoc false
  alias Uppy.{DBAction, Storage}

  @behaviour Uppy.Phase

  @completed :completed

  @impl true
  def run(
        %{
          state: :unresolved,
          bucket: bucket,
          query: query,
          schema_data: schema_data,
          destination_object: dest_object
        } = input,
        opts
      ) do
    IO.inspect(input, label: "INPUT")
    src_object = schema_data.key

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
               status: @completed,
               key: dest_object,
               e_tag: metadata.e_tag,
               content_length: metadata.content_length,
               last_modified: metadata.last_modified
             },
             opts
           ),
         {:ok, _} <- Storage.delete_object(bucket, src_object, opts) do
      {:ok,
       %{
         input
         | state: :resolved,
           schema_data: schema_data
       }}
    end
  end

  # fallback
  def run(resolution, _opts) do
    {:ok, resolution}
  end
end
