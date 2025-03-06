defmodule Uppy.PathBuilders.StoragePathBuilder do
  @moduledoc false

  @behaviour Uppy.PathBuilder

  @default_encoding :encode32

  @encodings ~w(encode16 encode32 encode64)a

  @default_hash_size 4

  @organization "organization"

  @user "user"

  @temp "temp"

  @empty_string ""

  def build_permanent_object_path(%_{filename: filename} = struct, unique_identifier, opts) do
    path_prefix = opts[:prefix] || @empty_string

    partition_name = opts[:partition_name] || @organization

    reverse_partition_id? = Keyword.get(opts, :reverse_partition_id, false)

    partition_id = opts[:partition_id]

    callback_fun = opts[:callback]

    resource_name = underscore_last_module_alias(struct.__struct__)

    unique_identifier =
      if Keyword.get(opts, :unique_identifier_enabled, true) do
        unique_identifier || generate_unique_identifier(opts)
      end

    basename =
      if is_nil(unique_identifier) do
        filename
      else
        "#{unique_identifier}-#{filename}"
      end

    if is_function(callback_fun, 2) do
      case callback_fun.(struct, basename) do
        {basename, path} -> {URI.encode(basename), URI.encode(path)}
        term -> raise "Expected {basename, path}, got: #{inspect(term)}"
      end
    else
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

  def build_temporary_object_path(filename, opts) do
    path_prefix = opts[:prefix] || @temp

    reverse_partition_id? = Keyword.get(opts, :reverse_partition_id, false)

    partition_id = opts[:partition_id]

    partition_name = opts[:partition_name] || @user

    callback_fun = opts[:callback]

    resource_name = opts[:resource_name] || @empty_string

    basename_prefix =
      case opts[:basename_prefix] do
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
        rand_bytes =
          opts
          |> Keyword.get(:hash_size, @default_hash_size)
          |> :crypto.strong_rand_bytes()

        encoding_opts =
          opts
          |> Keyword.take([:padding])
          |> Keyword.put_new(:padding, false)

        apply(Base, encoding, [rand_bytes, encoding_opts])

      fun when is_function(fun) ->
        fun.()

      term ->
        raise "Expected one of #{inspect(@encodings)}, or a 0-arity function, got: #{inspect(term)}"
    end
  end

  defp underscore_last_module_alias(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
