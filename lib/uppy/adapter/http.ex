defmodule Uppy.Adapter.HTTP do
  @moduledoc """
  Adapter for executing HTTP requests.
  """

  @type url :: binary()
  @type headers :: list(binary())
  @type body :: any()
  @type options :: keyword()
  @type status :: non_neg_integer()

  @type http_response :: %{
          optional(atom()) => any(),
          body: body(),
          status: status(),
          headers: headers()
        }

  @type t_response :: {:ok, http_response()} | {:error, any()}

  @doc """
  Executes a HTTP HEAD request.
  """
  @callback head(url(), headers(), options()) :: t_response()

  @doc """
  Executes a HTTP GET request.
  """
  @callback get(url(), headers(), options()) :: t_response()

  @doc """
  Executes a HTTP DELETE request.
  """
  @callback delete(url(), headers(), options()) :: t_response()

  @doc """
  Executes a HTTP POST request.
  """
  @callback post(url(), headers(), body(), options()) :: t_response()

  @doc """
  Executes a HTTP PATCH request.
  """
  @callback patch(url(), headers(), body(), options()) :: t_response()

  @doc """
  Executes a HTTP PUT request.
  """
  @callback put(url(), headers(), body(), options()) :: t_response()
end
