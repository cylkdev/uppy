defmodule Uppy.HTTP do
  @moduledoc """
  # Uppy.HTTP

  `Uppy.HTTP` defines the behavior for HTTP adapters, providing a
  standardized interface for making HTTP requests. It specifies
  the required callback functions that any HTTP adapter must
  implement and their behaviour. By adhering to this behavior,
  custom adapters can seamlessly integrate with the system,
  enabling flexibility in choosing or swapping out underlying
  HTTP implementations.
  """
  @type url :: binary()
  @type headers :: list(binary())
  @type body :: any()
  @type opts :: keyword()
  @type status :: non_neg_integer()

  @type http_response :: {
          body(),
          %{
            optional(atom()) => any(),
            body: body(),
            status: status(),
            headers: headers()
          }
        }

  @type t_res :: {:ok, http_response()} | {:error, any()}

  @doc """
  Executes a HTTP HEAD request.
  """
  @callback head(url(), headers(), opts()) :: t_res()

  @doc """
  Executes a HTTP GET request.
  """
  @callback get(url(), headers(), opts()) :: t_res()

  @doc """
  Executes a HTTP DELETE request.
  """
  @callback delete(url(), headers(), opts()) :: t_res()

  @doc """
  Executes a HTTP POST request.
  """
  @callback post(url(), headers(), body(), opts()) :: t_res()

  @doc """
  Executes a HTTP PATCH request.
  """
  @callback patch(url(), headers(), body(), opts()) :: t_res()

  @doc """
  Executes a HTTP PUT request.
  """
  @callback put(url(), headers(), body(), opts()) :: t_res()

  @default_adapter Uppy.HTTP.Finch

  @doc """
  Executes a HTTP HEAD request.

  ### Examples

      iex> Uppy.HTTP.head("http://url.com")
  """
  @spec head(url(), headers(), opts()) :: t_res()
  def head(url, headers, opts) do
    adapter(opts).head(url, headers, opts)
  end

  @doc """
  Executes a HTTP GET request.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com")
  """
  @spec get(url(), headers(), opts()) :: t_res()
  def get(url, headers, opts) do
    adapter(opts).get(url, headers, opts)
  end

  @doc """
  Executes a HTTP DELETE request.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com")
  """
  @spec delete(url(), headers(), opts()) :: t_res()
  def delete(url, headers, opts) do
    adapter(opts).delete(url, headers, opts)
  end

  @doc """
  Executes a HTTP POST request.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", "body")
  """
  @spec post(url(), body(), headers(), opts()) :: t_res()
  def post(url, body, headers, opts) do
    adapter(opts).post(url, body, headers, opts)
  end

  @doc """
  Executes a HTTP PATCH request.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", "body")
  """
  @spec patch(url(), body(), headers(), opts()) :: t_res()
  def patch(url, body, headers, opts) do
    adapter(opts).patch(url, body, headers, opts)
  end

  @doc """
  Executes a HTTP PUT request.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", "body")
  """
  @spec put(url(), body(), headers(), opts()) :: t_res()
  def put(url, body, headers, opts) do
    adapter(opts).put(url, body, headers, opts)
  end

  defp adapter(opts) do
    opts[:http_adapter] || @default_adapter
  end
end
