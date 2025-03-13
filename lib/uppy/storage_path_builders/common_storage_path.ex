defmodule Uppy.StoragePathBuilder.CommonStoragePath do
  @moduledoc false

  @behaviour Uppy.StoragePathBuilder

  @default_encoding :encode32

  @encodings ~w(encode16 encode32 encode64)a

  @default_hash_size 4

  @organization "organization"

  @user "user"

  @temp "temp"

  @empty_string ""

  @impl true
  def build_storage_path(_action, %_{filename: filename} = struct, unique_identifier,  params, opts) do
    params = params[:permanent_object] || %{}

    path_prefix = params[:prefix] || @empty_string

    partition_name = params[:partition_name] || @organization

    callback_fun = params[:callback]

    resource_name = params[:resource_name] || underscore_name(struct.__struct__)

    unique_identifier = unique_identifier || generate_unique_identifier(opts)

    basename = "#{unique_identifier}-#{filename}"

    if is_function(callback_fun, 2) do
      case callback_fun.(struct, basename) do
        {basename, path} -> {URI.encode(basename), URI.encode(path)}
        term -> raise "Expected {basename, path}, got: #{inspect(term)}"
      end
    else
      reverse_partition_id? = Map.get(params, :reverse_partition_id, false)

      partition_id = params[:partition_id]

      partition_id =
        if reverse_partition_id? and not is_nil(partition_id) do
          if reverse_partition_id? do
            partition_id |> to_string() |> String.reverse()
          else
            partition_id
          end
        end

      path =
        Path.join([
          path_prefix,
          Enum.join([partition_id, partition_name], "-"),
          resource_name,
          basename
        ])

      {URI.encode(basename), URI.encode(path)}
    end
  end

  @impl true
  def build_storage_path(_action, filename, params, _opts) do
    params = params[:temporary_object] || %{}

    path_prefix = params[:prefix] || @temp

    partition_name = params[:partition_name] || @user

    callback_fun = params[:callback]

    resource_name = params[:resource_name] || @empty_string

    basename_prefix =
      case params[:basename_prefix] do
        nil -> :os.system_time() |> to_string() |> String.reverse()
        prefix -> prefix
      end

    basename =
      if basename_prefix in [nil, ""] do
        filename
      else
        "#{basename_prefix}-#{filename}"
      end

    if is_function(callback_fun, 2) do
      case callback_fun.(filename) do
        {basename, path} -> {URI.encode(basename), URI.encode(path)}
        term -> raise "Expected {basename, path}, got: #{inspect(term)}"
      end
    else
      reverse_partition_id? = Map.get(params, :reverse_partition_id, false)

      partition_id = params[:partition_id]

      partition_id =
        if reverse_partition_id? and not is_nil(partition_id) do
          if reverse_partition_id? do
            partition_id |> to_string() |> String.reverse()
          else
            partition_id
          end
        end

      path =
        Path.join([
          path_prefix,
          Enum.join([partition_id, partition_name], "-"),
          resource_name,
          basename
        ])

      {URI.encode(basename), URI.encode(path)}
    end
  end

  defp generate_unique_identifier(opts) do
    case Keyword.get(opts, :encoding, @default_encoding) do
      encoding when encoding in @encodings ->
        bytes =
          opts
          |> Keyword.get(:hash_size, @default_hash_size)
          |> :crypto.strong_rand_bytes()

        encoding_opts =
          opts
          |> Keyword.take([:padding])
          |> Keyword.put_new(:padding, false)

        apply(Base, encoding, [bytes, encoding_opts])

      fun when is_function(fun) ->
        fun.()

      term ->
        raise "Expected one of #{inspect(@encodings)}, or a 0-arity function, got: #{inspect(term)}"
    end
  end

  defp underscore_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
