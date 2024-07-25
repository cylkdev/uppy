defmodule Uppy.HTTP do
  @moduledoc """
  This module dispatches HTTP requests to the http adapter.
  """
  alias Uppy.{Config, Utils}

  @logger_prefix "Uppy.HTTP"

  @default_http_adapter Uppy.Adapters.HTTP.Finch

  def head(url, headers, options) do
    Utils.Logger.debug(@logger_prefix, "HEAD url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}")

    response =
      url
      |> http_adapter!(options).head(headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "HEAD url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  def get(url, headers, options) do
    Utils.Logger.debug(@logger_prefix, "GET url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}")

    response =
      url
      |> http_adapter!(options).get(headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "GET url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  def delete(url, headers, options) do
    Utils.Logger.debug(@logger_prefix, "DELETE url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}")

    response =
      url
      |> http_adapter!(options).delete(headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "DELETE url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  def post(url, headers, body, options) do
    Utils.Logger.debug(@logger_prefix, "POST url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}, body=#{inspect(body)}")

    response =
      url
      |> http_adapter!(options).post(body, headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "POST url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  def patch(url, headers, body, options) do
    Utils.Logger.debug(@logger_prefix, "PATCH url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}, body=#{inspect(body)}")

    response =
      url
      |> http_adapter!(options).patch(body, headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "PATCH url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  def put(url, headers, body, options) do
    Utils.Logger.debug(@logger_prefix, "PUT url=#{inspect(url)}, headers=#{inspect(headers)}, options=#{inspect(options)}, body=#{inspect(body)}")

    response =
      url
      |> http_adapter!(options).put(body, headers, http_options!(options))
      |> handle_response()

    Utils.Logger.debug(@logger_prefix, "PUT url=#{inspect(url)}\n\nresponse:\n\n#{inspect(response)}")

    response
  end

  defp handle_response({:ok, {_raw_body, _response}} = ok), do: ok
  defp handle_response({:error, _error} = error), do: error
  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, {raw_body(), response()}}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end

  defp http_options!(options), do: Keyword.get(options, :http_options, [])
  defp http_adapter!(options) do
    Keyword.get(options, :http_adapter, Config.http_adapter()) || @default_http_adapter
  end
end
