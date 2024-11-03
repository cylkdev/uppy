defmodule Uppy.ObjectPaths.TemporaryObjectPath do

  @behaviour Uppy.ObjectPath

  @prefix "temp"

  @doc """
  ...
  """
  @doc since: "2.5.0"
  @impl true
  def build_object_path(id, partition_name, basename, opts) do
    "#{prefix!(opts)}/#{reverse_id(id, opts)}-#{partition_name}/#{basename}"
  end

  @doc """
  ...
  """
  @doc since: "2.5.0"
  @impl true
  def validate_object_path(path, opts) do
    with :ok <- check_prefix(path, opts),
      {:ok, {prefix, partition, basename}} <- parse_path(path),
      {:ok, {id, partition_name}} <- parse_partition(partition, path, opts) do
      {:ok, %{
        prefix: prefix,
        id: id,
        partition_name: partition_name,
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
          "temporary object path partition should have 2 segments",
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
      [prefix, partition, basename] -> {:ok, {prefix, partition, basename}}
      segments ->
        {
          :error,
          "temporary object path should have 3 segments",
          %{
            path: path,
            segments: segments,
            object_path: __MODULE__
          }
        }
    end
  end

  defp check_prefix(path, opts) do
    if String.starts_with?(path, prefix!(opts)) do
      :ok
    else
      {
        :error,
        "temporary object path prefix is invalid",
        %{
          path: path,
          object_path: __MODULE__
        }
      }
    end
  end

  defp prefix!(opts) do
    opts[:temporary_object_prefix] || @prefix
  end

  defp reverse_id(id, opts) do
    if Keyword.get(opts, :reverse_id, true) do
      id |> to_string() |> String.reverse()
    else
      id
    end
  end
end
