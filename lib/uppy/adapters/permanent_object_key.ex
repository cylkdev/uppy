defmodule Uppy.Adapters.PermanentObjectKey do
  @moduledoc """
  ...
  """

  @behaviour Uppy.Adapter.PermanentObjectKey

  @default_prefix ""

  @prefix Application.compile_env(__MODULE__, :prefix, @default_prefix)

  if !(@prefix === "") and !String.ends_with?(@prefix, "/") do
    raise "Expected prefix to end with /, got: #{inspect(@prefix)}"
  end

  @doc """
  ...
  """
  def decode_path([prefix, partition_key, resource_name, basename]) do
    {:ok, %{
      prefix: prefix,
      partition_key: partition_key,
      resource_name: URI.decode_www_form(resource_name),
      basename: URI.decode_www_form(basename)
    }}
  end

  def decode_path([partition_key, resource_name, basename]) do
    prefix = ""

    decode_path([prefix, partition_key, resource_name, basename])
  end

  def decode_path(path) when is_binary(path) do
    path |> Path.split() |> decode_path()
  end

  def decode_path(path) do
    {:error, Uppy.Error.call(:forbidden, "cannot decode permanent object path", %{path: path})}
  end

  @doc """
  Returns true is string starts with `#{@prefix}`.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def validate(path) do
    with {:ok, path} <- ensure_starts_with_prefix(path),
      {:ok, _} <- decode_path(path) do
      {:ok, path}
    end
  end

  defp ensure_starts_with_prefix(path) do
    prefix = prefix()

    if String.starts_with?(path, prefix) do
      {:ok, path}
    else
      {:error, Uppy.Error.call(:forbidden, "invalid permanent object key", %{
        path: path,
        prefix: prefix
      })}
    end
  end

  @doc """
  Reverses the `id` and encodes the string to www form params.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def encode_id(id) do
    id |> to_string() |> String.reverse() |> URI.encode_www_form()
  end

  @doc """
  Decodes an encoded id string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def decode_id(encoded_id) do
    encoded_id |> URI.decode_www_form() |> String.reverse()
  end

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
  def prefix(id), do: Path.join([prefix(), "#{encode_id(id)}-"])

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.PermanentObjectKey
  def prefix, do: @prefix
end
