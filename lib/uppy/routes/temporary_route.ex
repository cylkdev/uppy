defmodule Uppy.Routes.TemporaryRoute do
  @moduledoc """
  Keys are namespaces as `temp/<id>-global/<basename>`
  """

  @behaviour Uppy.Route

  @type params :: Uppy.Route.params()
  @type basename :: Uppy.Route.basename()
  @type path :: Uppy.Route.path()
  @type options :: Uppy.Route.options()

  @temp "temp"

  @doc """
  Implementation for `c:Uppy.Route.valid?/1`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.valid?("temp/01-global/unique_identifier-image.jpeg")
      true
  """
  @impl true
  @spec valid?(path :: path()) :: boolean()
  def valid?(path), do: match?({:ok, _}, validate(path))

  @doc """
  Implementation for `c:Uppy.Route.validate/1`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.validate("temp/01-global/unique_identifier-image.jpeg")
      {:ok, %{
        prefix: "temp",
        partition_id: "10",
        partition_name: "user",
        basename: "unique_identifier-image.jpeg"
      }}
  """
  @impl true
  @spec validate(path :: path()) :: {:ok, term()} | {:error, term()}
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
      [prefix, partition, basename] -> {:ok, {prefix, partition, basename}}
      _ -> {:error, ErrorMessage.forbidden("invalid path", %{path: path})}
    end
  end

  @doc """
  Implementation for `c:Uppy.Route.path/2`

  ### Examples

      iex> Uppy.Routes.TemporaryRoute.path("unique_identifier-image.jpeg", %{id: 10, partition_name: "global"})
      "temp/01-global/unique_identifier-image.jpeg"
  """
  @impl true
  @spec path(basename :: basename(), params :: params()) :: path()
  def path(basename, %{id: id, partition_name: partition_name} = params) do
    URI.encode("#{params[:prefix] || @temp}/#{reverse_id(id)}-#{partition_name}/#{basename}")
  end

  defp reverse_id(id) do
    id |> to_string() |> String.reverse()
  end
end
