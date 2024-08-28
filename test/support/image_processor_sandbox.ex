defmodule Uppy.Support.ImageProcessorSandbox do
  @moduledoc false

  @sleep 10
  @state "state"
  @disabled "disabled_pids"
  @registry :image_processor_sandbox
  @keys :unique

  @type action :: :put_result
  @type bucket :: binary()
  @type source_object :: binary()
  @type destination_object :: binary()
  @type params :: map()
  @type options :: keyword

  @spec start_link :: {:error, any} | {:ok, pid}
  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  @spec put_result_response(bucket, source_object, params, destination_object, options) :: any
  def put_result_response(bucket, source_object, params, destination_object, options) do
    func = find!(:put_result, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(source_object)

      2 ->
        func.(source_object, params)

      3 ->
        func.(source_object, params, destination_object)

      4 ->
        func.(source_object, params, destination_object, options)

      _ ->
        raise """
        This function's signature is not supported:

        #{inspect(func)}

        Please provide a function that takes between zero to two args:

        fn -> ... end
        fn (source_object) -> ... end
        fn (source_object, params) -> ... end
        fn (source_object, params, destination_object) -> ... end
        fn (source_object, params, destination_object, options) -> ... end
        """
    end
  end

  @doc """
  Set sandbox responses in test. Call this function in your setup block with a list of tuples.

  The tuples have two elements:
  - The first element is either a string bucket or a regex that needs to match on the bucket

  ```elixir
  Uppy.Support.Adapters.ImageProcessor.Sandbox.set_put_result_responses([{"bucket", fn ->
    {:ok, [
      %{
        e_tag: "etag",
        key: "key.txt",
        last_modified: ~U[2023-08-18 10:53:21.000Z],
        owner: nil,
        size: 11,
        storage_class: "STANDARD"
      }
    ]}
  end}])
  ```
  """
  @spec set_put_result_responses([{binary(), fun}]) :: :ok
  def set_put_result_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:put_result, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @doc """
  Sets current pid to use actual caches rather than sandboxed

  import Uppy.Support.ImageProcessorSandbox, only: [disable_s3_sandbox: 1]

  setup :disable_s3_sandbox
  """
  @spec disable_s3_sandbox(map) :: :ok
  def disable_s3_sandbox(_context) do
    with {:error, :registry_not_started} <-
           SandboxRegistry.register(@registry, @disabled, %{}, @keys) do
      raise_not_started!()
    end
  end

  @doc "Check if sandbox for current pid was disabled by disable_s3_sandbox/1"
  @spec sandbox_disabled? :: boolean
  def sandbox_disabled? do
    case SandboxRegistry.lookup(@registry, @disabled) do
      {:ok, _} -> true
      {:error, :registry_not_started} -> raise_not_started!()
      {:error, :pid_not_registered} -> false
    end
  end

  @doc """
  Finds out whether its PID or one of its ancestor's PIDs have been registered
  Returns response function or raises an error for developer
  """
  @spec find!(action, bucket) :: fun
  def find!(action, bucket) do
    case SandboxRegistry.lookup(@registry, @state) do
      {:ok, funcs} ->
        find_response!(funcs, action, bucket)

      {:error, :pid_not_registered} ->
        raise """
        No functions registered for #{inspect(self())}
        Action: #{inspect(action)}
        bucket: #{inspect(bucket)}

        ======= Use: =======
        #{format_example(action, bucket)}
        === in your test ===
        """

      {:error, :registry_not_started} ->
        raise """
        Registry not started for #{inspect(__MODULE__)}.
        Please add the line:

        #{inspect(__MODULE__)}.start_link()

        to test_helper.exs for the current app.
        """
    end
  end

  defp find_response!(funcs, action, bucket) do
    key = {action, bucket}

    with funcs when is_map(funcs) <- Map.get(funcs, key, funcs),
         regexes <- Enum.filter(funcs, fn {{_, k}, _v} -> is_struct(k, Regex) end),
         {_regex, func} when is_function(func) <-
           Enum.find(regexes, funcs, fn {{key, regex}, _v} ->
             Regex.match?(regex, bucket) and key === action
           end) do
      func
    else
      func when is_function(func) ->
        func

      functions when is_map(functions) ->
        functions_text =
          Enum.map_join(functions, "\n", fn {k, v} -> "#{inspect(k)}    =>    #{inspect(v)}" end)

        raise """
        Function not found for #{inspect({action, bucket})} in #{inspect(self())}
        Found:
        #{functions_text}

        ======= Use: =======
        #{format_example(action, bucket)}
        === in your test ===
        """

      other ->
        raise """
        Unrecognized input for #{inspect(key)} in #{inspect(self())}

        Did you use
        fn -> function() end
        in your set_get_responses/1 ?

        Found:
        #{inspect(other)}

        ======= Use: =======
        #{format_example(action, bucket)}
        === in your test ===
        """
    end
  end

  defp format_example(action, bucket) do
    """
    alias Uppy.Support.ImageProcessorSandbox

    setup do
      ImageProcessorSandbox.set_#{action}_responses([
        {#{inspect(bucket)}, fn _object, _options -> _response end},
        # or
        {#{inspect(bucket)}, fn _object -> _response end},
        # or
        {#{inspect(bucket)}, fn -> _response end}
        # or
        {~r|http://na1|, fn -> _response end}
      ])
    end
    """
  end

  defp raise_not_started! do
    raise """
    Registry not started for #{inspect(__MODULE__)}.
    Please add the line:

    #{inspect(__MODULE__)}.start_link()

    to test_helper.exs for the current app.
    """
  end
end
