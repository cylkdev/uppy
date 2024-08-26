defmodule Uppy.Storages.S3.HTTP do
  @moduledoc """
  ...
  """
  alias Uppy.HTTP

  def request(:get, url, _body, headers, options) do
    url
    |> HTTP.get(headers, options)
    |> handle_response()
  end

  def request(:head, url, _body, headers, options) do
    url
    |> HTTP.head(headers, options)
    |> handle_response()
  end

  def request(:delete, url, _body, headers, options) do
    url
    |> HTTP.delete(headers, options)
    |> handle_response()
  end

  def request(:post, url, body, headers, options) do
    url
    |> HTTP.post(body, headers, options)
    |> handle_response()
  end

  def request(:put, url, body, headers, options) do
    url
    |> HTTP.put(body, headers, options)
    |> handle_response()
  end

  def request(method, url, body, headers) do
    request(method, url, body, headers, [])
  end

  defp handle_response({:ok, {body, %{status: status, headers: headers, body: _body}}}) do
    {:ok, %{
      status_code: status,
      body: body,
      headers: headers
    }}
  end

  defp handle_response({:error, %{message: message}}) when is_binary(message) do
    {:error, %{reason: message}}
  end

  defp handle_response({:error, message}) when is_binary(message) do
    {:error, %{reason: message}}
  end
end
