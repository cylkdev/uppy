defmodule Uppy.HTTP do
  @definition [
    json_adapter: [
      type: :atom,
      doc: "Sets the JSON adapter for encoding and decoding."
    ],
    http_adapter: [
      type: :atom,
      doc: "Sets the HTTP adapter module used to make requests."
    ],
    http_options: [
      type: :keyword_list,
      doc: "HTTP adapter module options."
    ],
    disable_json_encoding?: [
      type: :boolean,
      default: false,
      doc: "Sets if http responses should be encoded to json."
    ],
    disable_json_decoding?: [
      type: :boolean,
      default: false,
      doc: "Sets if http responses should be decoded from json."
    ],
    atomize_keys?: [
      type: :boolean,
      doc: "Sets if the keys in http responses should be converted to atoms."
    ],
    max_retries: [
      type: :non_neg_integer,
      doc: "The number of times to retry a http request before aborting."
    ],
    max_timeout: [
      type: :non_neg_integer,
      doc: "The maximum amount of time to wait when retrying a request in milliseconds."
    ]
  ]

  @moduledoc """
  This module dispatches HTTP requests to the http adapter.

  ### Options
  #{NimbleOptions.docs(@definition)}
  """
  alias Uppy.{Config, Utils}
  alias Uppy.HTTP.Encoder

  @type t_res(t) :: Uppy.t_res(t)

  @type api_key :: Uppy.api_key()

  @type options :: Uppy.options()

  @typedoc "URL to make a HTTP request."
  @type http_url :: binary

  @typedoc "A list of key-value pairs sent as headers in a HTTP request."
  @type http_headers :: [{binary | atom, binary}]

  @typedoc "Payload sent in a HTTP request."
  @type http_body :: term

  @typedoc "The response from the HTTP adapter."
  @type http_response :: %{
          body: term,
          status: non_neg_integer,
          headers: [{binary | atom, binary}]
        }

  @logger_prefix "Uppy.HTTP"

  @default_options [
    host: "http://localhost:8108",
    http_adapter: Uppy.Adapters.HTTP.Finch,
    http_options: [],
    disable_json_encoding?: false,
    disable_json_decoding?: false,
    max_retries: 10,
    max_timeout: 30_000
  ]

  @doc """
  Executes a HTTP HEAD request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.head("http://url.com")
  """
  def head(url, headers, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: HEAD
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.head(url, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  @doc """
  Executes a HTTP GET request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.get("http://url.com")
  """
  def get(url, headers, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: GET
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.get(url, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  @doc """
  Executes a HTTP DELETE request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.delete("http://url.com")
  """
  def delete(url, headers, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: DELETE
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.delete(url, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  @doc """
  Executes a HTTP POST request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.post("http://url.com", %{})
  """
  def post(url, headers, body, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: POST
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      body: #{inspect(body, pretty: true)}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.post(url, body, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  @doc """
  Executes a HTTP PATCH request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.patch("http://url.com", %{})
  """
  def patch(url, headers, body, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: PATCH
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      body: #{inspect(body, pretty: true)}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.patch(url, body, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  @doc """
  Executes a HTTP PUT request using the http adapter.

  ### Examples

      iex> Uppy.HTTP.put("http://url.com", %{})
  """
  def put(url, headers, body, options \\ []) do
    options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)

    http_adapter = Keyword.get(options, :http_adapter, Config.http_adapter())
    http_options = Keyword.get(options, :http_options, [])

    body = encode_json!(body, options)

    Utils.Logger.debug(
      @logger_prefix,
      """
      action: PUT
      encoding: JSON
      adapter: #{inspect(http_adapter)}
      url: #{url}
      body: #{inspect(body, pretty: true)}
      headers: #{inspect(headers)}
      options: #{inspect(http_options, pretty: true)}
      """
    )

    fn ->
      http_adapter.put(url, body, headers, http_options)
    end
    |> maybe_retry_on_error(options)
    |> handle_json_response(options)
  end

  defp maybe_retry_on_error(func, options) do
    case options[:max_retries] do
      0 ->
        func.()

      max_retries ->
        # The retry with exponential backoff can take an unspecified amount
        # of time to complete so we run it inside another task and await
        # the response for a max amount of time.
        fn ->
          retry_with_backoff(func, max_retries)
        end
        |> Task.async()
        |> Task.await(options[:max_timeout])
    end
  end

  defp retry_with_backoff(fun, attempt \\ 0, max_retries) do
    with {:error, error} <- fun.() do
      if attempt < max_retries do
        attempt = attempt + 1

        Utils.Logger.warning(
          @logger_prefix,
          "Retrying failed HTTP request. Making attempt #{attempt} out of #{max_retries})."
        )

        timeout = round(10 * :math.pow(2, attempt)) + Enum.random(50..150)

        :timer.sleep(timeout)

        retry_with_backoff(fun, attempt, max_retries)
      else
        {:error, error}
      end
    end
  end

  defp encode_json!(body, options) do
    if options[:disable_json_encoding?] === true do
      body
    else
      Encoder.encode_json!(body, options)
    end
  end

  defp handle_json_response({:ok, %{body: body}}, options) do
    if options[:disable_json_decoding?] === true do
      {:ok, body}
    else
      with {:ok, data} <- Encoder.decode_json(body, options) do
        {:ok, maybe_atomize_keys(data, options)}
      end
    end
  end

  defp handle_json_response({:error, _} = e, _), do: e

  defp maybe_atomize_keys(val, options) do
    if Keyword.get(options, :atomize_keys?) === true do
      Utils.atomize_keys(val)
    else
      val
    end
  end
end
