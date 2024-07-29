defmodule Uppy.PermanentObjectKeys.Default do
  @moduledoc """
  ...
  """

  alias Uppy.Error

  @behaviour Uppy.Adapter.PermanentObjectKey

  @default_prefix ""
  @default_postfix "uploads"

  @prefix Application.compile_env(__MODULE__, :prefix, @default_prefix)
  @postfix Application.compile_env(__MODULE__, :postfix, @default_postfix)

  if !(@prefix === "") and !String.ends_with?(@prefix, "/") do
    raise "Expected prefix to end with /, got: #{inspect(@prefix)}"
  end

  if String.contains?(@postfix, "/") do
    raise "Postfix cannot contain `/`, got: #{inspect(@postfix)}"
  end

  @doc """
  ...
  """
  def decode_path([prefix, partition_key, resource_name, basename] = path) do
    case validate_partition_key(partition_key) do
      :ok ->
        {:ok,
         %{
           prefix: prefix,
           partition_key: partition_key,
           resource_name: URI.decode_www_form(resource_name),
           basename: URI.decode_www_form(basename)
         }}

      :error ->
        {:error,
         Error.forbidden(
           "Expected partition key to be a binary in the format `<ID>-<POSTFIX>` at position '2' in path",
           %{
             path: path,
             prefix: prefix,
             partition_key: partition_key,
             resource_name: resource_name,
             basename: basename
           }
         )}
    end
  end

  def decode_path([partition_key, resource_name, basename]) do
    decode_path([nil, partition_key, resource_name, basename])
  end

  def decode_path(path) when is_binary(path) do
    path |> Path.split() |> decode_path()
  end

  def decode_path(value) do
    {:error, Error.forbidden("Expected a binary or list", %{value: value})}
  end

  @doc """
  Returns true is string starts with `#{@prefix}`.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def validate(path) do
    with {:ok, path} <- ensure_starts_with_prefix(path) do
      decode_path(path)
    end
  end

  @doc """
  Reverses the `id` and encodes the string to www form params.
  """
  def encode_id(id) do
    id |> to_string() |> String.reverse() |> URI.encode_www_form()
  end

  @doc """
  Decodes an encoded id string.
  """
  def decode_id(encoded_id) do
    encoded_id |> URI.decode_www_form() |> String.reverse()
  end

  def partition_key(id), do: "#{encode_id(id)}-#{@postfix}"

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def prefix(id, resource_name, basename) do
    Path.join([prefix(id, resource_name), URI.encode_www_form(basename)])
  end

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def prefix(id, resource_name), do: prefix(id) <> URI.encode_www_form(resource_name)

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def prefix(id), do: Path.join([prefix(), partition_key(id)])

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def prefix, do: @prefix

  @doc """
  Returns the postfix string.
  """
  def postfix, do: @postfix

  defp ensure_starts_with_prefix(path) do
    prefix = prefix()

    if String.starts_with?(path, prefix) do
      {:ok, path}
    else
      {:error,
       Uppy.Error.forbidden(
         "Expected path to start with prefix",
         %{
           path: path,
           prefix: prefix
         }
       )}
    end
  end

  defp validate_partition_key(partition_key) do
    case String.split(partition_key, "-") do
      [_id, @postfix] -> :ok
      _term -> :error
    end
  end
end
