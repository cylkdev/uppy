if Code.ensure_loaded?(Finch) do
  defmodule Uppy.HTTP.Finch do
    @default_name __MODULE__
    @default_pool_config [size: 1]
    @default_opts [
      name: @default_name,
      disable_json_decoding?: false,
      disable_json_encoding?: false,
      atomize_keys?: false,
      http: [get: nil, post: nil, sandbox: Mix.env() === :test],
      pools: [default: @default_pool_config]
    ]

    # NimbleOpts definition

    @definition [
      name: [type: :atom, default: :http_shared],
      snake_case_keys?: [type: :boolean, default: true],
      atomize_keys?: [type: :boolean, default: false],
      disable_json_decoding?: [type: :boolean, default: false],
      disable_json_encoding?: [type: :boolean, default: false],
      params: [type: :any],
      stream: [type: {:fun, 2}],
      stream_origin_callback: [type: {:fun, 1}],
      stream_acc: [type: :any],
      receive_timeout: [type: :pos_integer],
      pools: [
        # It's a map
        type: :any,
        default: %{default: @default_pool_config}
      ],
      http: [
        type: :keyword_list,
        default: [get: nil, post: nil, sandbox: Mix.env() === :test]
      ]
    ]

    @moduledoc """
    Defines a Finch based HTTP adapter.

    This module implements `Uppy.HTTP`

    ### Getting started

    You must start this adapter in your `application.ex` file:

    ```elixir
    defmodule YourApp.Application do
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        opts = [strategy: :one_for_one, name: YourApp.Supervisor]
        Supervisor.start_link(children(), opts)
      end

      def children do
        [
          Uppy.HTTP.Finch
        ]
      end
    end
    ```

    ### Shared Options
    #{NimbleOptions.docs(@definition)}

    ## Retries

    This module provides a built-in mechanism for retrying failed
    HTTP requests using exponential backoff.

    ### Exponential Backoff Calculation

    An exponential backoff equation is used to determine the time
    between retry attempts:

    `t𝑛 = t0 * 2ⁿ * (1 + rand())`

    where:

      * `t𝑛` - The time (in milliseconds) to wait **before** making
        the `n`-th retry attempt.

      * `t0` - The initial delay (in milliseconds).

      * `n` - The number of retries attempted so far.

      * `rand()` - A random number between 0 and 1, used to introduce
        jitter and prevent synchronized retries.

    ### Configuration Options

    The behavior of exponential backoff can be configured using the
    following options:

      * `:exponential_backoff_function` - (optional) A `2-arity` function that takes the
        `attempt` count and `opts` as arguments. This function must return a positive
        integer representing the sleep time in milliseconds. If provided, this function
        **completely replaces** the default exponential backoff calculation, meaning
        `:max`, `:delay`, and `:jitter` options will be ignored.

      * `:exponential_backoff_max` - The maximum backoff time (in milliseconds).
        The retry delay will never exceed this value.

      * `:exponential_backoff_delay` - The initial delay `t0` (in milliseconds) before
        the first retry.

      * `:exponential_backoff_jitter` - A random number between 0 and 1 used to modify
        the computed backoff time. By default, jitter is **multiplicative** (`t𝑛 * (1 + rand())`),
        preventing synchronized retries.

    ### Example

    Assuming `t0 = 100ms`, `n = 2` (third attempt), and `rand() = 0.5`, the delay would be:

    ```elixir
    t𝑛 = 100 * 2² * (1 + 0.5) = 100 * 4 * 1.5 = 600ms
    ```
    """

    alias Uppy.{
      Error,
      HTTP.Finch.Response,
      JSONEncoder,
      Utils
    }

    @type t_res() :: {:ok, Response.t()} | {:error, term()}
    @type headers :: [{binary | atom, binary}]

    @logger_prefix "Uppy.HTTP.Finch"

    @default_max_retries 10
    @one_hundred 100
    @two_minutes_millisecond 120_000

    @doc """
    Starts a GenServer process linked to the current process.
    """
    @spec start_link() :: GenServer.on_start()
    @spec start_link(name :: atom()) :: GenServer.on_start()
    @spec start_link(name :: atom(), opts :: keyword()) :: GenServer.on_start()
    def start_link(name \\ @default_name, opts \\ []) do
      opts
      |> Keyword.put(:name, name)
      |> NimbleOptions.validate!(@definition)
      |> Keyword.update!(:pools, &ensure_default_pool_exists/1)
      |> Finch.start_link()
    end

    defp ensure_default_pool_exists(pool_configs) when is_list(pool_configs) do
      pool_configs |> Map.new() |> ensure_default_pool_exists
    end

    defp ensure_default_pool_exists(%{default: _} = pool_config), do: pool_config

    defp ensure_default_pool_exists(pool_config) do
      Map.put(pool_config, :default, @default_pool_config)
    end

    @doc "Returns a supervisor child spec."
    @spec child_spec(atom | {atom, keyword} | keyword) :: %{id: atom, start: tuple}
    def child_spec(name) when is_atom(name) do
      %{
        id: name,
        start: {Uppy.HTTP.Finch, :start_link, [name]}
      }
    end

    def child_spec({name, opts}) do
      %{
        id: name,
        start: {Uppy.HTTP.Finch, :start_link, [name, opts]}
      }
    end

    def child_spec(opts) do
      opts = Keyword.put_new(opts, :name, @default_name)

      %{
        id: opts[:name],
        start: {Uppy.HTTP.Finch, :start_link, [opts[:name], opts]}
      }
    end

    @doc false
    @spec make_head_request(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def make_head_request(url, headers, opts) do
      request = Finch.build(:head, url, headers)

      stream_or_request(request, opts)
    end

    @doc false
    @spec make_get_request(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def make_get_request(url, headers, opts) do
      request = Finch.build(:get, url, headers)

      stream_or_request(request, opts)
    end

    @doc false
    @spec make_delete_request(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def make_delete_request(url, headers, opts) do
      request = Finch.build(:delete, url, headers)

      stream_or_request(request, opts)
    end

    @doc false
    @spec make_patch_request(
            url :: binary(),
            body :: term() | nil,
            headers :: headers(),
            opts :: keyword()
          ) :: t_res()
    def make_patch_request(url, body, headers, opts) do
      body = encode_json!(body, opts)

      request = Finch.build(:patch, url, headers, body)

      stream_or_request(request, opts)
    end

    @doc false
    @spec make_post_request(
            url :: binary(),
            body :: term() | nil,
            headers :: headers(),
            opts :: keyword()
          ) :: t_res()
    def make_post_request(url, body, headers, opts) do
      body = encode_json!(body, opts)

      request = Finch.build(:post, url, headers, body)

      stream_or_request(request, opts)
    end

    @doc false
    @spec make_put_request(
            url :: binary(),
            body :: term() | nil,
            headers :: headers(),
            opts :: keyword()
          ) :: t_res()
    def make_put_request(url, body, headers, opts) do
      body = encode_json!(body, opts)

      request = Finch.build(:put, url, headers, body)

      stream_or_request(request, opts)
    end

    defp stream_or_request(request, opts) do
      Uppy.Utils.Logger.debug(
        @logger_prefix,
        "stream_or_request | BEGIN | handling request\n\n#{inspect(request, pretty: true)}"
      )

      if opts[:stream] do
        Uppy.Utils.Logger.debug(@logger_prefix, "stream_or_request | INFO | streaming request")

        Finch.stream(
          request,
          opts[:name],
          opts[:stream_acc] || [],
          opts[:stream],
          opts
        )
      else
        max_retries = opts[:max_retries] || @default_max_retries

        retry_enabled? = max_retries not in [0, false]

        if retry_enabled? do
          Uppy.Utils.Logger.debug(@logger_prefix, "stream_or_request | INFO | retry enabled")

          retryable_request(request, 0, max_retries, opts)
        else
          Uppy.Utils.Logger.debug(@logger_prefix, "stream_or_request | INFO | retry disabled")

          make_request(request, opts)
        end
      end
    end

    defp retryable_request(request, attempt, max_retries, opts) do
      with {:error, _} = error <- make_request(request, opts) do
        if attempt < max_retries do
          delay = exponential_backoff(attempt, opts)

          Uppy.Utils.Logger.warning(
            @logger_prefix,
            """
            HTTP request failed on attempt #{attempt} of #{max_retries}. Retrying in #{delay}ms...

            error:

            #{inspect(error)}
            """
          )

          :timer.sleep(delay)

          retryable_request(request, attempt + 1, max_retries, opts)
        else
          Uppy.Utils.Logger.warning(
            @logger_prefix,
            """
            HTTP request failed after #{max_retries} attempts.

            error:

            #{inspect(error)}
            """
          )

          error
        end
      end
    end

    defp make_request(request, opts) do
      with {:ok, response} <- Finch.request(request, opts[:name], opts) do
        response = %Response{
          request: request,
          body: response.body,
          status: response.status,
          headers: response.headers
        }

        Uppy.Utils.Logger.debug(
          @logger_prefix,
          "make_request | OK | response\n\n#{inspect(response, pretty: true)}"
        )

        {:ok, response}
      end
    end

    defp append_query_params(url, nil), do: url

    defp append_query_params(url, params) do
      "#{url}?#{params |> encode_query_params |> Enum.join("&")}"
    end

    defp encode_query_params(params) do
      Enum.flat_map(params, fn
        {k, v} when is_list(v) -> Enum.map(v, &encode_key_value(k, &1))
        {k, v} -> [encode_key_value(k, v)]
      end)
    end

    defp encode_key_value(key, value), do: URI.encode_query(%{key => value})

    @doc """
    Executes a HTTP PATCH request.

    ### Examples

        iex> Uppy.HTTP.Finch.patch("http://url.com", nil)
    """
    @spec patch(url :: binary(), body :: term() | nil, headers :: headers(), opts :: keyword()) ::
            t_res()
    def patch(url, body, headers, opts \\ []) do
      Utils.Logger.debug(
        @logger_prefix,
        "patch BEGIN | url=#{inspect(url)}, body=#{inspect(body)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)
      http_patch = opts[:http][:patch] || (&make_patch_request/4)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_patch.(body, headers, opts)
      end
      |> run_and_measure(headers, "PATCH", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "patch | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "patch | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP POST request.

    ### Examples

        iex> Uppy.HTTP.Finch.post("http://url.com", nil)
    """
    @spec post(url :: binary(), body :: term() | nil, headers :: headers(), opts :: keyword()) ::
            t_res()
    def post(url, body, headers, opts) do
      Utils.Logger.debug(
        @logger_prefix,
        "post BEGIN | url=#{inspect(url)}, body=#{inspect(body)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)
      http_post = opts[:http][:post] || (&make_post_request/4)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_post.(body, headers, opts)
      end
      |> run_and_measure(headers, "POST", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "post | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "post | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP PUT request.

    ### Examples

        iex> Uppy.HTTP.Finch.put("http://url.com", nil)
    """
    @spec put(url :: binary(), body :: term() | nil, headers :: headers(), opts :: keyword()) ::
            t_res()
    def put(url, body, headers, opts) do
      Utils.Logger.debug(
        @logger_prefix,
        "put BEGIN | url=#{inspect(url)}, body=#{inspect(body)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)
      http_put = opts[:http][:put] || (&make_put_request/4)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_put.(body, headers, opts)
      end
      |> run_and_measure(headers, "PUT", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "put | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "put | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP HEAD request.

    ### Examples

        iex> Uppy.HTTP.Finch.head("http://url.com")
    """
    @spec head(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def head(url, headers, opts) do
      Utils.Logger.debug(
        @logger_prefix,
        "head BEGIN | url=#{inspect(url)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)
      http_head = opts[:http][:head] || (&make_head_request/3)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_head.(headers, opts)
      end
      |> run_and_measure(headers, "HEAD", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "head | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "head | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP GET request.

    ### Examples

        iex> Uppy.HTTP.Finch.get("http://url.com")
    """
    @spec get(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def get(url, headers, opts) do
      Utils.Logger.debug(
        @logger_prefix,
        "get BEGIN | url=#{inspect(url)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)

      http_get = opts[:http][:get] || (&make_get_request/3)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_get.(headers, opts)
      end
      |> run_and_measure(headers, "GET", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "get | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "get | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP DELETE request.

    ### Examples

        iex> Uppy.HTTP.Finch.delete("http://url.com")
    """
    @spec delete(url :: binary(), headers :: headers(), opts :: keyword()) :: t_res()
    def delete(url, headers, opts) do
      Utils.Logger.debug(
        @logger_prefix,
        "delete BEGIN | url=#{inspect(url)}, headers=#{inspect(headers)}"
      )

      opts = @default_opts |> Keyword.merge(opts) |> NimbleOptions.validate!(@definition)
      http_delete = opts[:http][:delete] || (&make_delete_request/3)

      fn ->
        url
        |> append_query_params(opts[:params])
        |> http_delete.(headers, opts)
      end
      |> run_and_measure(headers, "DELETE", opts)
      |> handle_response(opts)
    rescue
      # Nimble pool out of workers error
      e in RuntimeError ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "delete | ERROR | runtime error occurred #{inspect(e)}"
        )

        {:error,
         Error.call(:service_unavailable, "HTTP request failed due to an unrecoverable error")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        Uppy.Utils.Logger.error(
          @logger_prefix,
          "delete | ERROR | process exited with reason #{inspect(reason)}"
        )

        {:error,
         Error.call(
           :service_unavailable,
           "HTTP connection pool exited with reason: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    defp run_and_measure(fnc, headers, method, opts) do
      start_time = System.monotonic_time()

      response = fnc.()

      metadata = %{
        start_time: System.system_time(),
        request: %{
          method: method,
          headers: headers
        },
        response: response,
        opts: opts
      }

      end_time = System.monotonic_time()

      measurements = %{elapsed_time: end_time - start_time}

      :telemetry.execute([:http, Keyword.get(opts, :name)], measurements, metadata)

      response
    end

    defp handle_response({:ok, %Response{status: status, body: raw_body} = res}, opts)
         when status in 200..299 do
      if raw_body in ["", nil] or opts[:disable_json_decoding?] === true do
        {:ok, {raw_body, res}}
      else
        case JSONEncoder.decode_json(raw_body, opts) do
          {:ok, json_body} ->
            body =
              json_body
              |> maybe_to_snake_case(opts)
              |> maybe_atomize_keys(opts)

            {:ok, {body, res}}

          {:error, _} = e ->
            {:error,
             Error.call(:internal_server_error, "failed to decode json", %{
               error: e,
               body: raw_body,
               response: res
             })}
        end
      end
    end

    defp handle_response({:ok, %Response{status: code} = res}, opts) do
      api_name = opts[:name]

      details = %{
        response: res,
        http_code: code,
        api_name: api_name
      }

      error_code_map = error_code_map(api_name)

      if Map.has_key?(error_code_map, code) do
        {error, message} = Map.get(error_code_map, code)

        {:error, Error.call(error, message, details)}
      else
        message = unknown_error_message(api_name)

        {:error, Error.call(:internal_server_error, message, details)}
      end
    end

    defp handle_response({:error, e}, opts) when is_binary(e) or is_atom(e) do
      message = "#{opts[:name]}: #{e}"

      {:error, Error.call(:internal_server_error, message, %{error: e})}
    end

    defp handle_response({:error, %Mint.TransportError{reason: :timeout} = e}, opts) do
      message = "#{opts[:name]}: Endpoint timeout."

      {:error, Error.call(:request_timeout, message, %{error: e})}
    end

    defp handle_response({:error, %Mint.TransportError{reason: :econnrefused} = e}, opts) do
      message = "#{opts[:name]}: HTTP connection refused."

      {:error, Error.call(:service_unavailable, message, %{error: e})}
    end

    defp handle_response({:error, e}, opts) do
      message = unknown_error_message(opts[:name])

      {:error, Error.call(:internal_server_error, message, %{error: e})}
    end

    defp handle_response(e, opts) do
      message = unknown_error_message(opts[:name])

      {:error, Error.call(:internal_server_error, message, %{error: e})}
    end

    defp unknown_error_message(api_name) do
      "#{api_name}: unknown error occurred"
    end

    # See docs: https://uppy.org/docs/0.25.1/api/api-errors.html
    defp error_code_map(api_name) do
      %{
        400 =>
          {:bad_request,
           "#{api_name}: The request could not be understood due to malformed syntax."},
        401 => {:unauthorized, "#{api_name}: API key is wrong."},
        404 => {:not_found, "#{api_name}: The requested resource is not found."},
        409 => {:conflict, "#{api_name}: Resource already exists."},
        422 =>
          {:unprocessable_entity, "#{api_name}: Request is well-formed, but cannot be processed."},
        503 =>
          {:service_unavailable,
           "#{api_name}: Uppy is temporarily offline. Please try again later."}
      }
    end

    defp encode_json!(body, opts) do
      if opts[:disable_json_encoding?] === true do
        Uppy.Utils.Logger.debug(@logger_prefix, "encode_json! | INFO | JSON encoding disabled")

        body
      else
        Uppy.Utils.Logger.debug(@logger_prefix, "encode_json! | INFO | encoding body to JSON")

        JSONEncoder.encode_json!(body, opts)
      end
    end

    defp maybe_to_snake_case(string, opts) do
      if Keyword.get(opts, :snake_case_keys?, true) do
        ProperCase.to_snake_case(string)
      else
        string
      end
    end

    defp maybe_atomize_keys(map, opts) do
      if Keyword.get(opts, :atomize_keys?, true) do
        Utils.atomize_keys(map)
      else
        map
      end
    end

    defp exponential_backoff(attempt, opts) do
      max = opts[:exponential_backoff_max] || @two_minutes_millisecond
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
      (delay * :math.pow(2, attempt) * (50 + jitter))
      |> min(max)
      |> round()
    end
  end
else
  if Uppy.Config.http_adapter() === Uppy.HTTP.Finch do
    raise """
    Uppy is configured to use the http adapter `Uppy.HTTP.Finch`
    which requires the dependency `finch`. To fix this error you must add `finch`
    as a dependency to your project's mix.exs file:

    ```
    # mix.exs
    def deps do
      [
        {:finch, "~> 0.16.0"}
      ]
    end
    ```

    Don't forget add the adapter to your application supervision children:

    ```
    # application.ex
    def start(_type, _args) do
      children = [
        Uppy.HTTP.Finch
      ]

      ...
    end
    ```

    or configure a different http adapter:

    ```
    # config.exs
    config :elixir_uppy, :http_adapter, YourApp.HTTPAdapter
    ```
    """
  end
end
