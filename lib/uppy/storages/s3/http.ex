defmodule Uppy.Storages.S3.HTTP do
  @moduledoc """
  ...
  """
  alias Uppy.HTTP

  @default_opts [
    disable_json_encoding?: true,
    disable_json_decoding?: true
  ]

  def request(:get, url, _body, headers, opts) do
    opts = Keyword.merge(@default_opts, opts)

    url
    |> HTTP.get(headers, opts)
    |> handle_response()
  end

  def request(:head, url, _body, headers, opts) do
    opts = Keyword.merge(@default_opts, opts)

    url
    |> HTTP.head(headers, opts)
    |> handle_response()
  end

  def request(:delete, url, _body, headers, opts) do
    opts = Keyword.merge(@default_opts, opts)

    url
    |> HTTP.delete(headers, opts)
    |> handle_response()
  end

  def request(:post, url, body, headers, opts) do
    opts = Keyword.merge(@default_opts, opts)

    url
    |> HTTP.post(body, headers, opts)
    |> handle_response()
  end

  def request(:put, url, body, headers, opts) do
    opts = Keyword.merge(@default_opts, opts)

    url
    |> HTTP.put(body, headers, opts)
    |> handle_response()
  end

  def request(method, url, headers, body) do
    request(method, url, headers, body, [])
  end

  defp handle_response({:error, %{message: message}}) when is_binary(message) do
    {:error, %{reason: message}}
  end

  defp handle_response({:error, message}) when is_binary(message) do
    {:error, %{reason: message}}
  end

  defp handle_response({:ok, {body, %{status: status, headers: headers, body: _body}}}) do
    {:ok, %{
      status_code: status,
      body: body,
      headers: headers
    }}
  end
end
