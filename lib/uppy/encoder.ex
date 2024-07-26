defmodule Uppy.Encoder do
  @default_json_adapter Jason

  @moduledoc """
  Encode / Decode JSON

  ## Options

      * `json_adapter` - JSON adapter module. Defaults to #{@default_json_adapter}
  """
  alias Uppy.Config

  @doc """
  Decodes JSON string.

  ### Examples

      iex> Uppy.Encoder.decode_json("{\"likes\":10}")
      {:ok, %{"likes" => 10}}
  """
  @spec decode_json(term(), keyword()) :: binary()
  def decode_json(term, options \\ []) do
    json_adapter!(options).decode(term)
  end

  @doc """
  Decodes JSON string.

  ### Examples

      iex> Uppy.Encoder.decode_json!("{\"likes\":10}")
      %{"likes" => 10}
  """
  @spec decode_json!(term(), keyword()) :: binary()
  def decode_json!(term, options \\ []) do
    json_adapter!(options).decode!(term)
  end

  @doc """
  Encodes to JSON string.

  ### Examples

      iex> Uppy.Encoder.encode_json(%{likes: 10})
      {:ok, "{\"likes\":10}"}
  """
  @spec encode_json(term(), keyword()) :: binary()
  def encode_json(term, options \\ []) do
    json_adapter!(options).encode(term)
  end

  @doc """
  Encodes to JSON string.

  ### Examples

      iex> Uppy.Encoder.encode_json!(%{likes: 10})
      "{\"likes\":10}"
  """
  @spec encode_json!(term(), keyword()) :: binary()
  def encode_json!(term, options \\ []) do
    json_adapter!(options).encode!(term)
  end

  defp json_adapter!(options) do
    Keyword.get(options, :json_adapter, Config.json_adapter()) || @default_json_adapter
  end
end
