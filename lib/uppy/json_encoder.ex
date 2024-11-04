defmodule Uppy.JSONEncoder do
  @moduledoc """
  Encode and Decode JSON
  """
  alias Uppy.Config

  @default_json_adapter Jason

  @doc ~S"""
  Decodes JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.decode_json("{\"likes\":10}", json_adapter: Jason)
      {:ok, %{"likes" => 10}}
  """
  @spec decode_json(term(), keyword()) :: {:ok, map()} | {:error, term()}
  def decode_json(term, opts) do
    json_adapter!(opts).decode(term)
  end

  @doc ~S"""
  Decodes JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.decode_json!("{\"likes\":10}", json_adapter: Jason)
      %{"likes" => 10}
  """
  @spec decode_json!(term(), keyword()) :: binary()
  def decode_json!(term, opts) do
    json_adapter!(opts).decode!(term)
  end

  @doc ~S"""
  Encodes to JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.encode_json(%{likes: 10}, json_adapter: Jason)
      {:ok, "{\"likes\":10}"}
  """
  @spec encode_json(term(), keyword()) :: {:ok, binary()} | {:error, term()}
  def encode_json(term, opts) do
    json_adapter!(opts).encode(term)
  end

  @doc ~S"""
  Encodes to JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.encode_json!(%{likes: 10}, json_adapter: Jason)
      "{\"likes\":10}"
  """
  @spec encode_json!(term(), keyword()) :: binary()
  def encode_json!(term, opts) do
    json_adapter!(opts).encode!(term)
  end

  defp json_adapter!(opts) do
    Keyword.get(opts, :json_adapter, Config.json_adapter()) || @default_json_adapter
  end
end
