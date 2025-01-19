defmodule Uppy.StorageSandbox do
  @moduledoc false

  @sleep 10
  @state "state"
  @disabled "disabled_pids"
  @registry :uppy_storage_sandbox
  @keys :unique

  @type action ::
          :abort_multipart_upload
          | :complete_multipart_upload
          | :create_multipart_upload
          | :delete_object
          | :get_chunk
          | :get_object
          | :head_object
          | :list_multipart_uploads
          | :list_objects
          | :list_parts
          | :object_chunk_stream
          | :pre_sign
          | :put_object
          | :put_object_copy
  @type bucket :: binary()
  @type prefix :: binary()
  @type object :: binary()
  @type body :: term()
  @type options :: keyword()
  @type http_method ::
          :get | :head | :post | :put | :delete | :connect | :options | :trace | :patch
  @type upload_id :: binary()
  @type parts :: list(map())
  @type marker :: binary()
  @type start_byte :: non_neg_integer()
  @type end_byte :: non_neg_integer()
  @type chunk_size :: non_neg_integer()

  @spec start_link :: {:error, any} | {:ok, pid}
  def start_link do
    Registry.start_link(keys: @keys, name: @registry)
  end

  @spec object_chunk_stream_response(bucket, object, chunk_size, options) :: any
  def object_chunk_stream_response(bucket, object, chunk_size, options) do
    func = find!(:object_chunk_stream, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, chunk_size)

      3 ->
        func.(object, chunk_size, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to three (3) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, chunk_size) -> ... end
        fn (object, chunk_size, options) -> ... end
        """
    end
  end

  @spec get_chunk_response(bucket, object, start_byte, end_byte, options) :: any
  def get_chunk_response(bucket, object, start_byte, end_byte, options) do
    func = find!(:get_chunk, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, start_byte)

      3 ->
        func.(object, start_byte, end_byte)

      4 ->
        func.(object, start_byte, end_byte, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to four (4) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, start_byte) -> ... end
        fn (object, start_byte, end_byte) -> ... end
        fn (object, start_byte, end_byte, options) -> ... end
        """
    end
  end

  @spec list_objects_response(bucket, prefix, options) :: any
  def list_objects_response(bucket, prefix, options) do
    func = find!(:list_objects, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(prefix)

      2 ->
        func.(prefix, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to two (2) arguments.

        fn -> ... end
        fn (prefix) -> ... end
        fn (prefix, options) -> ... end
        """
    end
  end

  @spec get_object_response(bucket, object, options) :: any
  def get_object_response(bucket, object, options) do
    func = find!(:get_object, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to two (2) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, options) -> ... end
        """
    end
  end

  @spec head_object_response(bucket, object, options) :: any
  def head_object_response(bucket, object, options) do
    func = find!(:head_object, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to two (2) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, options) -> ... end
        """
    end
  end

  def sign_part_response(bucket, object, upload_id, part_number, options) do
    func = find!(:sign_part, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, upload_id)

      3 ->
        func.(object, upload_id, part_number)

      4 ->
        func.(object, upload_id, part_number, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to four (4) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, upload_id) -> ... end
        fn (object, upload_id, part_number) -> ... end
        fn (object, upload_id, part_number, options) -> ... end
        """
    end
  end

  @spec pre_sign_response(bucket, http_method, object, options) :: any
  def pre_sign_response(bucket, http_method, object, options) do
    func = find!(:pre_sign, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(http_method)

      2 ->
        func.(http_method, object)

      3 ->
        func.(http_method, object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to three (3) arguments.

        fn -> ... end
        fn (http_method) -> ... end
        fn (http_method, object) -> ... end
        fn (http_method, object, options) -> ... end
        """
    end
  end

  @spec list_multipart_uploads_response(bucket, options) :: any
  def list_multipart_uploads_response(bucket, options) do
    func = find!(:list_multipart_uploads, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to one (1) argument.

        fn -> ... end
        fn (options) -> ... end
        """
    end
  end

  @spec create_multipart_upload_response(bucket, object, options) :: any
  def create_multipart_upload_response(bucket, object, options) do
    func = find!(:create_multipart_upload, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to two (2) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, options) -> ... end
        """
    end
  end

  @spec list_parts_response(bucket, object, upload_id, options) :: any
  def list_parts_response(bucket, object, upload_id, options) do
    func = find!(:list_parts, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, upload_id)

      3 ->
        func.(object, upload_id, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to three (3) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, upload_id) -> ... end
        fn (object, upload_id, options) -> ... end
        """
    end
  end

  @spec abort_multipart_upload_response(bucket, object, upload_id, options) :: any
  def abort_multipart_upload_response(bucket, object, upload_id, options) do
    func = find!(:abort_multipart_upload, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, upload_id)

      3 ->
        func.(object, upload_id, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to three (3) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, upload_id) -> ... end
        fn (object, upload_id, options) -> ... end
        """
    end
  end

  @spec complete_multipart_upload_response(bucket, object, upload_id, parts, options) :: any
  def complete_multipart_upload_response(bucket, object, upload_id, parts, options) do
    func = find!(:complete_multipart_upload, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, upload_id)

      3 ->
        func.(object, upload_id, parts)

      4 ->
        func.(object, upload_id, parts, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to four (4) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, upload_id) -> ... end
        fn (object, upload_id, parts) -> ... end
        fn (object, upload_id, parts, options) -> ... end
        """
    end
  end

  @doc """
  Returns the response set for the current process.

  ### Examples

      iex> Uppy.StorageSandbox.put_object_copy_response("destination_bucket", "example_copy.txt", "source_bucket", "example.txt", [])
  """
  @spec put_object_copy_response(bucket(), object(), bucket(), object(), options()) :: any()
  def put_object_copy_response(
        destination_bucket,
        destination_object,
        source_bucket,
        source_object,
        options
      ) do
    func = find!(:put_object_copy, destination_bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(destination_object)

      2 ->
        func.(destination_object, source_bucket)

      3 ->
        func.(destination_object, source_bucket, source_object)

      4 ->
        func.(destination_object, source_bucket, source_object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to four (4) arguments.

        fn -> ... end
        fn (destination_object) -> ... end
        fn (destination_object, source_bucket) -> ... end
        fn (destination_object, source_bucket, source_object) -> ... end
        fn (destination_object, source_bucket, source_object, options) -> ... end
        """
    end
  end

  @doc """
  Returns the response set for the current process.

  ### Examples

      iex> Uppy.StorageSandbox.put_object_response("your_bucket", "example.txt", "Hello world!", [])
  """
  @spec put_object_response(bucket, object, body, options) :: any
  def put_object_response(bucket, object, body, options) do
    func = find!(:put_object, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      2 ->
        func.(object)

      3 ->
        func.(object, body)

      4 ->
        func.(object, body, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to three (3) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, body) -> ... end
        fn (object, body, options) -> ... end
        """
    end
  end

  @doc """
  Returns the response set for the current process.

  ### Examples

      iex> Uppy.StorageSandbox.delete_object_response("your_bucket", "example.txt", [])
  """
  @spec delete_object_response(bucket(), object(), options()) :: any()
  def delete_object_response(bucket, object, options) do
    func = find!(:delete_object, bucket)

    case :erlang.fun_info(func)[:arity] do
      0 ->
        func.()

      1 ->
        func.(object)

      2 ->
        func.(object, options)

      _ ->
        raise """
        Function arity not supported.

        #{inspect(func)}

        Please provide a function that takes zero (0) to two (2) arguments.

        fn -> ... end
        fn (object) -> ... end
        fn (object, options) -> ... end
        """
    end
  end

  @doc """
  Set sandbox responses in test. Call this function in your setup block with a list of tuples.

  The tuples have two elements:
  - The first element is either a string bucket or a regex that needs to match on the bucket

  ```elixir
  Uppy.Adapters.Storage.Sandbox.set_list_objects_responses([{"bucket", fn ->
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
  @spec set_list_objects_responses([{binary(), fun}]) :: :ok
  def set_list_objects_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:list_objects, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_download_stream_responses([{binary(), fun}]) :: :ok
  def set_download_stream_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:download_stream, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_get_chunk_responses([{binary(), fun}]) :: :ok
  def set_get_chunk_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:get_chunk, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_get_object_responses([{binary(), fun}]) :: :ok
  def set_get_object_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:get_object, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_head_object_responses([{binary(), fun}]) :: :ok
  def set_head_object_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:head_object, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_pre_sign_responses([{binary(), fun}]) :: :ok
  def set_pre_sign_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:pre_sign, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_sign_part_responses([{binary(), fun}]) :: :ok
  def set_sign_part_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:sign_part, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_list_multipart_uploads_responses([{binary(), fun}]) :: :ok
  def set_list_multipart_uploads_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:list_multipart_uploads, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_create_multipart_upload_responses([{binary(), fun}]) :: :ok
  def set_create_multipart_upload_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:create_multipart_upload, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_list_parts_responses([{binary(), fun}]) :: :ok
  def set_list_parts_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:list_parts, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_abort_multipart_upload_responses([{binary(), fun}]) :: :ok
  def set_abort_multipart_upload_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:abort_multipart_upload, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_complete_multipart_upload_responses([{binary(), fun}]) :: :ok
  def set_complete_multipart_upload_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:complete_multipart_upload, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_put_object_copy_responses([{binary(), fun}]) :: :ok
  def set_put_object_copy_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:put_object_copy, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_put_object_responses([{binary(), fun}]) :: :ok
  def set_put_object_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:put_object, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @spec set_delete_object_responses([{binary(), fun}]) :: :ok
  def set_delete_object_responses(tuples) do
    tuples
    |> Map.new(fn {bucket, func} -> {{:delete_object, bucket}, func} end)
    |> then(&SandboxRegistry.register(@registry, @state, &1, @keys))
    |> then(fn
      :ok -> :ok
      {:error, :registry_not_started} -> raise_not_started!()
    end)

    Process.sleep(@sleep)
  end

  @doc """
  Sets current pid to use actual caches rather than sandboxed

  import Uppy.StorageSandbox, only: [disable_storage_sandbox: 1]

  setup :disable_storage_sandbox
  """
  @spec disable_storage_sandbox(map) :: :ok
  def disable_storage_sandbox(_context) do
    with {:error, :registry_not_started} <-
           SandboxRegistry.register(@registry, @disabled, %{}, @keys) do
      raise_not_started!()
    end
  end

  @doc "Check if sandbox for current pid was disabled by disable_storage_sandbox/1"
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
         regex_list <- Enum.filter(funcs, fn {{_, k}, _v} -> is_struct(k, Regex) end),
         {_regex, func} when is_function(func) <-
           Enum.find(regex_list, funcs, fn {{key, regex}, _v} ->
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
    alias Uppy.StorageSandbox

    setup do
      StorageSandbox.set_#{action}_responses([
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
