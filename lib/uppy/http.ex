defmodule Uppy.HTTP do
  @moduledoc """
  This module dispatches HTTP requests to the http adapter.

  ## Retries

  This module provides a mechanism out-of-the-box for retrying failed requests.
  An exponential backoff equation is used to calculate the time between attempts.

  The default equation used for exponential backoff is:

  `t𝑛 = t0 * 2𝑛 * ( 1 + rand() )`

  where:

      * `t𝑛` - is the time to wait before the `𝑛` n-th retry attempt.
      * `t0` - is the initial delay.
      * `𝑛` - is the number of retries that have been attempted.
      * `rand()` - is a random number between 0 and 1. The randomness is added to mitigate synchronized retries.

  The behaviour of the exponential backoff can be configured via the following options:

      * `[:http][:exponential_backoff_function]` - A 2-arity function that is passed the number of
        `attempts` and `options` as the arguments. This function must return a positive integer
        for the amount of time to sleep. If this option is used `:max`, `:delay`, and `:jitter`
        will have no effect.

      * `[:http][:exponential_backoff][:max]` - The maximum amount of time to sleep.

      * `[:http][:exponential_backoff][:delay]` - The initial delay to wait when calculating the backoff.

      * `[:http][:exponential_backoff][:jitter]` - A random number between 0 and 1.
  """
  alias Uppy.{Config, Encoder, Utils}

  @type url :: Uppy.Adapter.HTTP.url()
  @type headers :: Uppy.Adapter.HTTP.headers()
  @type body :: Uppy.Adapter.HTTP.body()
  @type options :: Uppy.Adapter.HTTP.options()
  @type status :: Uppy.Adapter.HTTP.status()
  @type t_http_response :: Uppy.Adapter.HTTP.t_http_response()

  @logger_prefix "Uppy.HTTP"

  @default_max_retries 10
  @one_hundred 100
  @five_minutes 300_000

  @default_http_adapter Uppy.HTTP.Finch

  @doc """
  Executes a HTTP HEAD request.

  ### Examples

      iex> Uppy.HTTP.head("http://url.com", [])
  """
  @spec head(url(), headers(), options()) :: t_http_response()
  def head(url, headers, options) do
    fn ->
      url
      |> adapter!(options).head(headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP GET request.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com", [])
  """
  @spec get(url(), headers(), options()) :: t_http_response()
  def get(url, headers, options) do
    fn ->
      url
      |> adapter!(options).get(headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP DELETE request.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com", [])
  """
  @spec delete(url(), headers(), options()) :: t_http_response()
  def delete(url, headers, options) do
    fn ->
      url
      |> adapter!(options).delete(headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP POST request.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", [], "body")
  """
  @spec post(url(), headers(), body(), options()) :: t_http_response()
  def post(url, headers, body, options) do
    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).post(body, headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP PATCH request.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", [], "body")
  """
  @spec patch(url(), headers(), body(), options()) :: t_http_response()
  def patch(url, headers, body, options) do
    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).patch(body, headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP PUT request.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", [], "body")
  """
  @spec put(url(), headers(), body(), options()) :: t_http_response()
  def put(url, headers, body, options) do
    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).put(body, headers, http_options!(options))
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  # Exponential backoff equation: `b = x * 2^n * (1 + r)`
  #
  # `b` - is the time to wait before the n-th retry attempt.
  # `x` - the initial delay.
  # `n` - is the number of retries that have been attempted.
  # `r` - a random number between 0 and 1. The randomness is recommended to avoid synchronized retries which could cause a thundering herd problem.
  defp exponential_backoff(delay, attempt, jitter, max) do
    round(min(max, delay * :math.pow(2, attempt) * (1 + jitter)))
  end

  defp exponential_backoff(attempt, options) do
    case options[:http][:exponential_backoff_function] do
      nil ->
        max = options[:http][:exponential_backoff][:max] || @five_minutes
        delay = options[:http][:exponential_backoff][:delay] || @one_hundred
        jitter = options[:http][:exponential_backoff][:jitter] || :rand.uniform_real()

        unless jitter >= 0 and jitter <= 1 do
          raise "Expected `:jitter` to be a number between 0 and 1."
        end

        exponential_backoff(delay, attempt, jitter, max)

      func when is_function(func, 2) ->
        with term when not is_integer(term) or (is_integer(term) and term <= 0) <-
               func.(attempt, options) do
          raise "Expected the function passed to the option `:exponential_backoff` to return a positive integer, got: #{inspect(term)}"
        end

      term ->
        raise "Expected a 2-arity function for the option `:exponential_backoff_function`, got: #{inspect(term)}"
    end
  end

  defp maybe_retry(func, attempt, options) do
    case max_retries!(options) do
      disabled when disabled in [false, 0] ->
        Utils.Logger.debug(@logger_prefix, "retries disabled")

        func.()

      max_retries when is_integer(max_retries) and max_retries > 0 ->
        with {:error, _} = error <- func.() do
          if attempt < max_retries do
            backoff = exponential_backoff(attempt, options)

            Utils.Logger.debug(
              @logger_prefix,
              "sleeping for #{inspect(backoff)} ms (#{attempt + 1} / #{max_retries})"
            )

            :timer.sleep(backoff)

            maybe_retry(func, attempt + 1, options)
          else
            error
          end
        end

      term ->
        raise """
        Expected one of:

        `false`
        `0`
        `pos_integer()`

        got:
        #{inspect(term)}
        """
    end
  end

  defp maybe_retry(func, options) do
    maybe_retry(func, 0, options)
  end

  defp max_retries!(options) do
    Keyword.get(options, :max_retries, @default_max_retries)
  end

  defp encode_json!(body, options) do
    if options[:disable_json_encoding?] === true do
      body
    else
      Encoder.encode_json!(body, options)
    end
  end

  defp decode_json(body, options) do
    if options[:disable_json_decoding?] === true do
      {:ok, body}
    else
      with {:ok, data} <- Encoder.decode_json(body, options) do
        {:ok, maybe_atomize_keys(data, options)}
      end
    end
  end

  defp maybe_atomize_keys(map, options) do
    if Keyword.get(options, :atomize_keys?, true) do
      Utils.atomize_keys(map)
    else
      map
    end
  end

  defp deserialize_json_response({:ok, %{body: raw_body} = response}, options) do
    with {:ok, body} <- decode_json(raw_body, options) do
      {:ok, {body, response}}
    end
  end

  defp deserialize_json_response({:error, _} = error, _options) do
    error
  end

  defp handle_response({:ok, %{status: _, headers: _, body: _}} = ok), do: ok
  defp handle_response({:error, _} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, %{status: status(), headers: headers(), body: body()}}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end

  defp http_options!(options), do: Keyword.get(options, :http_options, [])

  defp adapter!(options) do
    Keyword.get(options, :http_adapter, Config.http_adapter()) || @default_http_adapter
  end
end
