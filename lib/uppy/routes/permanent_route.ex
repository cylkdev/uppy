defmodule Uppy.Routes.PermanentRoute do
  @moduledoc """
  Keys are namespaces as `<id>-company/<resource_name>/<basename>`
  """

  @behaviour Uppy.Route

  @doc """
  Implementation for `c:Uppy.Route.valid?/1`

  ### Examples

      iex> Uppy.Routes.PermanentRoute.valid?("01-company/company_avatars/unique_identifier-image.jpeg")
      true
  """
  @impl true
  @spec valid?(binary()) :: boolean()
  def valid?(path), do: match?({:ok, _}, validate(path))

  @doc """
  Implementation for `c:Uppy.Route.validate/1`

  ### Examples

      iex> Uppy.Routes.PermanentRoute.validate("01-company/company_avatars/unique_identifier-image.jpeg")
      {:ok, %{
        basename: "unique_identifier-image.jpeg",
        resource_name: "company_avatars",
        partition_id: "10",
        partition_name: "company"
      }}
  """
  @impl true
  def validate(path) do
    with {:ok, {partition, resource_name, basename}} <- split_path(path),
         {:ok, {partition_id, partition_name}} <- split_partition(partition, path) do
      {:ok,
       %{
         resource_name: resource_name,
         partition_id: String.reverse(partition_id),
         partition_name: partition_name,
         basename: basename
       }}
    end
  end

  defp split_partition(partition, path) do
    case String.split(partition, "-") do
      [partition_id, "company"] ->
        {:ok, {partition_id, "company"}}

      _ ->
        {:error,
         ErrorMessage.forbidden("invalid partition", %{
           partition: partition,
           path: path
         })}
    end
  end

  defp split_path(path) do
    case Path.split(path) do
      [partition, resource_name, basename] -> {:ok, {partition, resource_name, basename}}
      _ -> {:error, ErrorMessage.forbidden("invalid path", %{path: path})}
    end
  end

  @doc """
  Implementation for `c:Uppy.Route.path/2`

  ### Examples

      iex> Uppy.Routes.PermanentRoute.path("unique_identifier-image.jpeg", %{company_id: 10, resource_name: "company_avatars"})
      "01-company/company_avatars/unique_identifier-image.jpeg"
  """
  @impl true
  @spec path(binary(), map()) :: binary()
  def path(basename, %{company_id: company_id, resource_name: resource_name}) do
    URI.encode("#{reverse_id(company_id)}-company/#{resource_name}/#{basename}")
  end

  defp reverse_id(id) do
    id |> to_string() |> String.reverse()
  end
end
