defmodule Uppy.ObjectPaths.PermanentObjectPath do
  @behaviour Uppy.ObjectPath

  @doc """
  ...
  """
  @doc since: "2.5.0"
  @impl true
  def build_object_path(id, partition_name, basename, opts) when is_list(basename) do
    "#{reverse_id(id, opts)}-#{partition_name}/#{Enum.join(basename, "-")}"
  end

  def build_object_path(id, partition_name, basename, opts) do
    "#{reverse_id(id, opts)}-#{partition_name}/#{basename}"
  end

  @doc """
  ...
  """
  @doc since: "2.5.0"
  @impl true
  def validate_object_path(path, opts) do
    with {:ok, {partition, resource_name, basename}} <- parse_path(path),
      {:ok, {id, partition_name}} <- parse_partition(partition, path, opts) do
      {:ok, %{
        prefix: nil,
        id: id,
        partition_name: partition_name,
        resource_name: resource_name,
        basename: basename
      }}
    end
  end

  defp parse_partition(partition, path, opts) do
    case String.split(partition, "-") do
      [id, partition_name] -> {:ok, {reverse_id(id, opts), partition_name}}
      segments ->
        {
          :error,
          "permanent object partition should have 2 segments",
          %{
            path: path,
            segments: segments,
            object_path: __MODULE__
          }
        }
    end
  end

  defp parse_path(path) do
    case String.split(path, "/") do
      [partition, resource_name, basename] -> {:ok, {partition, resource_name, basename}}
      segments ->
        {
          :error,
          "permanent object path should have 3 segments",
          %{
            path: path,
            segments: segments,
            object_path: __MODULE__
          }
        }
    end
  end

  defp reverse_id(id, opts) do
    if Keyword.get(opts, :reverse_id, true) do
      id |> to_string() |> String.reverse()
    else
      id
    end
  end
end
