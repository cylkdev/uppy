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
  alias Uppy.{Config, JSONEncoder, Utils}

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

  @logger_prefix "Uppy.HTTP"

  @default_max_retries 10
  @one_hundred 100
  @two_minutes_ms 120_000

  @default_adapter Uppy.HTTP.Finch

  @doc """
  Executes a HTTP HEAD request.

  ### Examples

      iex> Uppy.HTTP.head("http://url.com")
  """
  @spec head(url(), headers(), opts()) :: t_res()
  def head(url, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    fn ->
      url
      |> adapter!(opts).head(headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  @doc """
  Executes a HTTP GET request.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com")
  """
  @spec get(url(), headers(), opts()) :: t_res()
  def get(url, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    fn ->
      url
      |> adapter!(opts).get(headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  @doc """
  Executes a HTTP DELETE request.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com")
  """
  @spec delete(url(), headers(), opts()) :: t_res()
  def delete(url, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    fn ->
      url
      |> adapter!(opts).delete(headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  @doc """
  Executes a HTTP POST request.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", "body")
  """
  @spec post(url(), body(), headers(), opts()) :: t_res()
  def post(url, body, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    body = encode_json!(body, opts)

    fn ->
      url
      |> adapter!(opts).post(body, headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  @doc """
  Executes a HTTP PATCH request.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", "body")
  """
  @spec patch(url(), body(), headers(), opts()) :: t_res()
  def patch(url, body, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    body = encode_json!(body, opts)

    fn ->
      url
      |> adapter!(opts).patch(body, headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  @doc """
  Executes a HTTP PUT request.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", "body")
  """
  @spec put(url(), body(), headers(), opts()) :: t_res()
  def put(url, body, headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])

    body = encode_json!(body, opts)

    fn ->
      url
      |> adapter!(opts).put(body, headers, http_opts)
      |> handle_response()
    end
    |> maybe_retry(opts)
    |> deserialize_json_response(opts)
  end

  defp exponential_backoff(attempt, opts) do
    case opts[:exponential_backoff_function] do
      nil ->
        max = opts[:exponential_backoff_max] || @two_minutes_ms
        delay = opts[:exponential_backoff_delay] || @one_hundred
        jitter = opts[:exponential_backoff_jitter] || :rand.uniform_real()

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
        func.(attempt, opts)

      term ->
        raise "Expected a 2-arity function for the option `:exponential_backoff_function`, got: #{inspect(term)}"
    end
  end

  defp maybe_retry(func, attempt, opts) do
    case max_retries!(opts) do
      disabled when disabled in [false, 0] ->
        func.()

      max_retries when is_integer(max_retries) and max_retries > 0 ->
        with {:error, _} = error <- func.() do
          if attempt < max_retries do
            Uppy.Utils.Logger.warning(
              @logger_prefix,
              """
              [#{inspect(attempt + 1)}/#{inspect(max_retries)}] Request failed, got error:

              #{inspect(error, pretty: true)}
              """
            )

            backoff = exponential_backoff(attempt, opts)

            :timer.sleep(backoff)

            maybe_retry(func, attempt + 1, opts)
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

  defp maybe_retry(func, opts) do
    maybe_retry(func, 0, opts)
  end

  defp max_retries!(opts) do
    Keyword.get(opts, :max_retries, @default_max_retries)
  end

  defp encode_json!(body, opts) do
    if opts[:disable_json_encoding?] === true do
      body
    else
      JSONEncoder.encode_json!(body, opts)
    end
  end

  defp decode_json(body, opts) do
    if (body in [nil, ""]) or (opts[:disable_json_decoding?] === true) do
      {:ok, body}
    else
      with {:ok, data} <- JSONEncoder.decode_json(body, opts) do
        {:ok, maybe_atomize_keys(data, opts)}
      end
    end
  end

  defp maybe_atomize_keys(map, opts) do
    if Keyword.get(opts, :atomize_keys?, true) do
      Utils.atomize_keys(map)
    else
      map
    end
  end

  defp deserialize_json_response({:ok, %{body: raw_body} = response}, opts) do
    with {:ok, body} <- decode_json(raw_body, opts) do
      {:ok, {body, response}}
    end
  end

  defp deserialize_json_response({:error, _} = error, _opts) do
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

  defp adapter!(opts) do
    opts[:http_adapter] || Config.http_adapter() || @default_adapter
  end
end
