defmodule Uppy.Routes.TemporaryRoute do
  @moduledoc """
  Keys are namespaces as `temp/<id>-user/<basename>`
  """

  @behaviour Uppy.Route

  @doc """
  Implementation for `c:Uppy.Route.valid?/1`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.valid?("temp/01-user/unique_identifier-image.jpeg")
      true
  """
  @impl true
  @spec valid?(binary()) :: boolean()
  def valid?(path), do: match?({:ok, _}, validate(path))

  @doc """
  Implementation for `c:Uppy.Route.validate/1`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.validate("temp/01-user/unique_identifier-image.jpeg")
      {:ok, %{
        prefix: "temp",
        partition_id: "10",
        partition_name: "user",
        basename: "unique_identifier-image.jpeg"
      }}
  """
  @impl true
  def validate(path) do
    with {:ok, {prefix, partition, basename}} <- split_path(path),
         {:ok, {partition_id, partition_name}} <- split_partition(partition, path) do
      {:ok,
       %{
         prefix: prefix,
         partition_id: String.reverse(partition_id),
         partition_name: partition_name,
         basename: basename
       }}
    end
  end

  defp split_partition(partition, path) do
    case String.split(partition, "-") do
      [partition_id, partition_name] ->
        {:ok, {partition_id, partition_name}}

      _ ->
        {:error,
         ErrorMessage.forbidden("invalid partition", %{
           path: path,
           partition: partition
         })}
    end
  end

  defp split_path(path) do
    case Path.split(path) do
      ["temp", partition, basename] -> {:ok, {"temp", partition, basename}}
      _ -> {:error, ErrorMessage.forbidden("invalid path", %{path: path})}
    end
  end

  @doc """
  Implementation for `c:Uppy.Route.path/2`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.path("unique_identifier-image.jpeg", %{user_id: 10})
      "temp/01-user/unique_identifier-image.jpeg"
  """
  @impl true
  @spec path(binary(), map()) :: binary()
  def path(basename, %{user_id: user_id}) do
    URI.encode("temp/#{reverse_id(user_id)}-user/#{basename}")
  end

  defp reverse_id(id) do
    id |> to_string() |> String.reverse()
  end
end
