defmodule Uppy.Adapters.TemporaryObjectKey do
  @moduledoc """
  ...
  """

  @behaviour Uppy.Adapter.TemporaryObjectKey

  @default_prefix "temp/"
  @default_postfix "user"

  @prefix Application.compile_env(__MODULE__, :prefix, @default_prefix)

  if !String.ends_with?(@prefix, "/") do
    raise "Expected prefix to end with /, got: #{inspect(@prefix)}"
  end

  @postfix Application.compile_env(__MODULE__, :postfix, @default_postfix)

  @doc """
  ...
  """
  def decode_path([prefix, partition, basename], _options) do
    {:ok,
     %{
       prefix: prefix,
       partition: partition,
       basename: URI.decode_www_form(basename)
     }}
  end

  def decode_path(path, options) when is_binary(path) do
    path |> Path.split() |> decode_path(options)
  end

  def decode_path(path, options) do
    {:error,
     Uppy.Error.call(:forbidden, "invalid temporary object key path", %{path: path}, options)}
  end

  @doc """
  Returns true is string starts with `#{@prefix}`.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def validate_path(path, options) do
    with {:ok, path} <- ensure_starts_with_prefix(path, options) do
      decode_path(path, options)
    end
  end

  defp ensure_starts_with_prefix(path, options) do
    prefix = prefix()

    if String.starts_with?(path, prefix) do
      {:ok, path}
    else
      {:error,
       Uppy.Error.call(
         :forbidden,
         "invalid temporary object key",
         %{
           path: path,
           prefix: prefix
         },
         options
       )}
    end
  end

  @doc """
  Reverses the `id` and encodes the string to www form params.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def encode_id(id) do
    id |> to_string() |> String.reverse() |> URI.encode_www_form()
  end

  @doc """
  Decodes an encoded id string.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def decode_id(encoded_id) do
    encoded_id |> URI.decode_www_form() |> String.reverse()
  end

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def prefix(id, basename), do: Path.join([prefix(id), URI.encode_www_form(basename)])

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def prefix(id), do: Path.join([prefix(), "#{encode_id(id)}-#{@postfix}"])

  @doc """
  Returns the prefix string.
  """
  @impl Uppy.Adapter.TemporaryObjectKey
  def prefix, do: @prefix
end
