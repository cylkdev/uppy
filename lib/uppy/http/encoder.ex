defmodule Uppy.HTTP.Encoder do
  @moduledoc """
  This module is responsible for JSON/JSONL encoding and decoding.
  """
  alias Uppy.Config

  @type t_res(t) :: Uppy.t_res(t)

  @doc ~S"""
  Encodes a term to a JSON string.

  ### Examples

      iex> Uppy.HTTP.Encoder.encode_json!([%{name: "foo"}, %{name: "bar"}])
      "[{\"name\":\"foo\"},{\"name\":\"bar\"}]"
  """
  @spec encode_json!(binary, keyword) :: binary
  def encode_json!(body, options \\ []) do
    json_adapter!(options).encode!(body)
  end

  @doc ~S"""
  Decodes a JSON string.

  ### Examples

      iex> Uppy.HTTP.Encoder.decode_json("[{\"name\":\"foo\"},{\"name\":\"bar\"}]")
      {:ok, [%{"name" => "foo"}, %{"name" => "bar"}]}
  """
  @spec decode_json(binary, keyword) :: t_res(map | list)
  def decode_json(body, options \\ []) when is_binary(body) do
    json_adapter!(options).decode(body)
  end

  defp json_adapter!(options) do
    Keyword.get(options, :json_adapter, Config.json_adapter())
  end
end
