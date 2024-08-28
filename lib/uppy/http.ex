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

  The behaviour of the exponential backoff can be configured via the following options:

    * `:exponential_backoff_function` - A 2-arity function that is passed the number
      of `attempts` and `options` as the arguments. This function must return a
      positive integer for the amount of time to sleep. If this option is used
      `:max`, `:delay`, and `:jitter` will have no effect.

    * `:exponential_backoff_max` - The maximum amount of time to sleep.

    * `:exponential_backoff_delay` - The initial delay to wait when calculating the
      backoff.

    * `:exponential_backoff_jitter` - A random number between 0 and 1.
  """
  alias Uppy.{Config, JSONEncoder, Utils}

  @type url :: Uppy.Adapter.HTTP.url()
  @type headers :: Uppy.Adapter.HTTP.headers()
  @type body :: Uppy.Adapter.HTTP.body()
  @type options :: Uppy.Adapter.HTTP.options()
  @type status :: Uppy.Adapter.HTTP.status()
  @type t_response :: Uppy.Adapter.HTTP.t_response()

  @logger_prefix "Uppy.HTTP"

  @default_max_retries 10
  @one_hundred 100
  @two_minutes_ms 120_000

  @default_http_adapter Uppy.HTTP.Finch

  @doc """
  Executes a HTTP HEAD request.

  ### Examples

      iex> Uppy.HTTP.head("http://url.com")
  """
  @spec head(url(), headers(), options()) :: t_response()
  def head(url, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    fn ->
      url
      |> adapter!(options).head(headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP GET request.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com")
  """
  @spec get(url(), headers(), options()) :: t_response()
  def get(url, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    fn ->
      url
      |> adapter!(options).get(headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP DELETE request.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com")
  """
  @spec delete(url(), headers(), options()) :: t_response()
  def delete(url, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    fn ->
      url
      |> adapter!(options).delete(headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP POST request.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", "body")
  """
  @spec post(url(), body(), headers(), options()) :: t_response()
  def post(url, body, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).post(body, headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP PATCH request.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", "body")
  """
  @spec patch(url(), body(), headers(), options()) :: t_response()
  def patch(url, body, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).patch(body, headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  @doc """
  Executes a HTTP PUT request.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", "body")
  """
  @spec put(url(), body(), headers(), options()) :: t_response()
  def put(url, body, headers \\ [], options \\ []) do
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    fn ->
      url
      |> adapter!(options).put(body, headers, http_options)
      |> handle_response()
    end
    |> maybe_retry(options)
    |> deserialize_json_response(options)
  end

  defp exponential_backoff(attempt, options) do
    case options[:exponential_backoff_function] do
      nil ->
        max = options[:exponential_backoff_max] || @two_minutes_ms
        delay = options[:exponential_backoff_delay] || @one_hundred
        jitter = options[:exponential_backoff_jitter] || :rand.uniform_real()

        unless jitter >= 0 and jitter <= 1 do
          raise "Expected option `:exponential_backoff_jitter` to be a number between 0 and 1, got: #{inspect(jitter)}"
        end

        # Exponential backoff equation:
        #
        # b = x * 2^n * (1 + r)
        #
        # `b` - The total time to wait before the n-th retry attempt.
        # `x` - The initial amount of time to wait.
        # `n` - The number of retries that have been attempted.
        # `r` - A random number between 0 and 1. The randomness is
        #       recommended to avoid synchronized retries which
        #       could cause a thundering herd problem.
        #
        (delay * :math.pow(2, attempt) * (1 + jitter)) |> min(max) |> round()

      func when is_function(func, 2) ->
        func.(attempt, options)

      term ->
        raise "Expected a 2-arity function for the option `:exponential_backoff_function`, got: #{inspect(term)}"
    end
  end

  defp maybe_retry(func, attempt, options) do
    case max_retries!(options) do
      disabled when disabled in [false, 0] ->
        func.()

      max_retries when is_integer(max_retries) and max_retries > 0 ->
        with {:error, _} = error <- func.() do
          if attempt < max_retries do
            Uppy.Utils.Logger.warn(
              @logger_prefix,
              """
              [#{inspect(attempt + 1)}/#{inspect(max_retries)}] Request failed, got error:

              #{inspect(error, pretty: true)}
              """
            )

            backoff = exponential_backoff(attempt, options)

            :timer.sleep(backoff)

            maybe_retry(func, attempt + 1, options)
          else
            error
          end
        end

      term ->
        raise """
        Option `:max_retries` must be `false`, `0`, or `pos_integer()`, got:

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
      JSONEncoder.encode_json!(body, options)
    end
  end

  defp decode_json(body, options) do
    if (body in [nil, ""]) or (options[:disable_json_decoding?] === true) do
      {:ok, body}
    else
      with {:ok, data} <- JSONEncoder.decode_json(body, options) do
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

    `{:ok, term()}`
    `{:error, term()}`

    got:

    #{inspect(term, pretty: true)}
    """
  end

  defp adapter!(options) do
    options[:http_adapter] || Config.http_adapter() || @default_http_adapter
  end
end
