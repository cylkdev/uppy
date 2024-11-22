defmodule Uppy.Storages.S3.HTTP do
  @moduledoc """
  ...
  """
  alias Uppy.HTTP

  @default_opts [
    disable_json_decoding?: true,
    disable_json_encoding?: true
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

  defp handle_response({:error, %{message: message}}) when is_binary(message) do
    {:error, %{reason: message}}
  end

  defp handle_response({:error, message}) when is_binary(message) do
    {:error, %{reason: message}}
  end

  defp handle_response({:ok, {_body, %{status: status, headers: headers, body: raw_body}}}) do
    {:ok,
     %{
       status_code: status,
       body: raw_body,
       headers: headers
     }}
  end
end
