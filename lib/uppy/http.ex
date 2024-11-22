defmodule Uppy.HTTP do
  @moduledoc """
  This module dispatches HTTP requests to the http adapter.

  ## Retries

  This module provides a mechanism out-of-the-box for retrying failed requests.
  An exponential backoff equation is used to calculate the time between attempts.

  The default equation used for exponential backoff is:

  `t𝑛 = t0 * 2𝑛 * (1 + rand())`

  where:

    * `t𝑛` - is the time to wait before the `𝑛` n-th retry attempt.

    * `t0` - is the initial delay.

    * `𝑛` - is the number of retries that have been attempted.

    * `rand()` - is a random number between 0 and 1. The randomness is added to
      mitigate synchronized retries.

  The behaviour of the exponential backoff can be configured via the following opts:

    * `:exponential_backoff_function` - A 2-arity function that is passed the number
      of `attempts` and `opts` as the arguments. This function must return a
      positive integer for the amount of time to sleep. If this option is used
      `:max`, `:delay`, and `:jitter` will have no effect.

    * `:exponential_backoff_max` - The maximum amount of time to sleep.

    * `:exponential_backoff_delay` - The initial delay to wait when calculating the
      backoff.

    * `:exponential_backoff_jitter` - A random number between 0 and 1.
  """
  alias Uppy.Config

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
    adapter!(opts).head(url, headers, opts)
  end

  @doc """
  Executes a HTTP GET request.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com")
  """
  @spec get(url(), headers(), opts()) :: t_res()
  def get(url, headers, opts) do
    adapter!(opts).get(url, headers, opts)
  end

  @doc """
  Executes a HTTP DELETE request.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com")
  """
  @spec delete(url(), headers(), opts()) :: t_res()
  def delete(url, headers, opts) do
    adapter!(opts).delete(url, headers, opts)
  end

  @doc """
  Executes a HTTP POST request.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", "body")
  """
  @spec post(url(), body(), headers(), opts()) :: t_res()
  def post(url, body, headers, opts) do
    adapter!(opts).post(url, body, headers, opts)
  end

  @doc """
  Executes a HTTP PATCH request.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", "body")
  """
  @spec patch(url(), body(), headers(), opts()) :: t_res()
  def patch(url, body, headers, opts) do
    adapter!(opts).patch(url, body, headers, opts)
  end

  @doc """
  Executes a HTTP PUT request.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", "body")
  """
  @spec put(url(), body(), headers(), opts()) :: t_res()
  def put(url, body, headers, opts) do
    adapter!(opts).put(url, body, headers, opts)
  end

  defp adapter!(opts) do
    opts[:http_adapter] || Config.http_adapter() || @default_adapter
  end
end
