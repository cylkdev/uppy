defmodule Uppy.Storage do
  @moduledoc """
  ...
  """
  alias Uppy.Config

  @type adapter :: atom()
  @type opts :: keyword()
  @type bucket :: binary()
  @type prefix :: binary()
  @type object :: binary()
  @type body :: term()
  @type http_method :: atom()
  @type e_tag :: binary()
  @type upload_id :: binary()
  @type marker :: binary()
  @type part_number :: pos_integer()
  @type part :: {part_number(), e_tag()}
  @type parts :: list(part())

  @type t_res :: {:ok, term()} | {:error, term()}

  @doc """
  ...
  """
  @callback list_objects(
    bucket :: bucket(),
    prefix :: prefix(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback get_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback head_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback presigned_url(
    bucket :: bucket(),
    http_method :: http_method(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback list_multipart_uploads(
    bucket :: bucket(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback initiate_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback list_parts(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback abort_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback complete_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    parts :: parts(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback put_object_copy(
    dest_bucket :: bucket(),
    destination_object :: object(),
    src_bucket :: bucket(),
    source_object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback put_object(
    bucket :: bucket(),
    object :: object(),
    body :: body(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback delete_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @default_adapter Uppy.Storages.S3

  @default_opts [
    storage: [sandbox: Mix.env() === :test]
  ]

  def download_chunk_stream(bucket, object, chunk_size, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_download_chunk_stream_response(bucket, object, chunk_size, opts)
    else
      bucket
      |> adapter!(opts).download_chunk_stream(object, chunk_size, opts)
      |> handle_response()
    end
  end

  def get_chunk(bucket, object, start_byte, end_byte, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts)
    else
      bucket
      |> adapter!(opts).get_chunk(object, start_byte, end_byte, opts)
      |> handle_response()
    end
  end

  @spec list_objects(
    bucket :: bucket(),
    prefix :: prefix(),
    opts :: opts()
  ) :: t_res()
  def list_objects(bucket, prefix, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_objects_response(bucket, prefix, opts)
    else
      bucket
      |> adapter!(opts).list_objects(prefix, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec get_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def get_object(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_object_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).get_object(object, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec head_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def head_object(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_head_object_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).head_object(object, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec presigned_download(
          bucket :: bucket(),
          object :: object(),
          opts :: opts()
        ) :: t_res()
  def presigned_download(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    presigned_url(bucket, :get, object, opts)
  end

  @doc """
  ...
  """
  @spec presigned_part_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    part_number :: part_number(),
    opts :: opts()
  ) :: t_res()
  def presigned_part_upload(
    bucket,
    object,
    upload_id,
    part_number,
    opts
  ) do
    query_params = %{
      "uploadId" => upload_id,
      "partNumber" => part_number
    }

    opts =
      @default_opts
      |> Keyword.merge(opts)
      |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))

    presigned_upload(bucket, object, opts)
  end

  @doc """
  ...
  """
  @spec presigned_upload(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def presigned_upload(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    case opts[:http_method] do
      nil -> presigned_url(bucket, :put, object, opts)
      http_method -> presigned_url(bucket, http_method, object, opts)
    end
  end

  @doc """
  ...
  """
  @spec presigned_url(
    bucket :: bucket(),
    http_method :: http_method(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def presigned_url(bucket, http_method, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_presigned_url_response(bucket, http_method, object, opts)
    else
      bucket
      |> adapter!(opts).presigned_url(http_method, object, opts)
      |> handle_response()
      |> handle_presigned_url_response()
    end
  end

  defp handle_presigned_url_response({:ok, %{url: url, expires_at: expires_at}} = ok)
       when is_binary(url) and is_struct(expires_at, DateTime) do
    ok
  end

  defp handle_presigned_url_response({:ok, term}) do
    raise """
    Expected one of:

    {:ok, %{url: binary(), expires_at: DateTime.t()}}
    {:error, term()}

    got:

    #{inspect(term, pretty: true)}
    """
  end

  defp handle_presigned_url_response(response) do
    response
  end

  @doc """
  ...
  """
  @spec list_multipart_uploads(bucket :: bucket(), opts :: opts()) :: t_res()
  def list_multipart_uploads(bucket, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_multipart_uploads_response(bucket, opts)
    else
      bucket
      |> adapter!(opts).list_multipart_uploads(opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec initiate_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def initiate_multipart_upload(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_initiate_multipart_upload_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).initiate_multipart_upload(object, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec list_parts(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    next_part_number_marker :: marker() | nil,
    opts :: opts()
  ) :: t_res()
  def list_parts(bucket, object, upload_id, next_part_number_marker, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_parts_response(bucket, object, upload_id, next_part_number_marker, opts)
    else
      bucket
      |> adapter!(opts).list_parts(object, upload_id, next_part_number_marker, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec abort_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    opts :: opts()
  ) :: t_res()
  def abort_multipart_upload(bucket, object, upload_id, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts)
    else
      bucket
      |> adapter!(opts).abort_multipart_upload(object, upload_id, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec complete_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    parts :: parts(),
    opts :: opts()
  ) :: t_res()
  def complete_multipart_upload(bucket, object, upload_id, parts, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, opts)
    else
      bucket
      |> adapter!(opts).complete_multipart_upload(object, upload_id, parts, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec put_object_copy(
    dest_bucket :: bucket(),
    destination_object :: object(),
    src_bucket :: bucket(),
    source_object :: object(),
    opts :: opts()
  ) :: t_res()
  def put_object_copy(
    dest_bucket,
    destination_object,
    src_bucket,
    source_object,
    opts
  ) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_copy_response(
        dest_bucket,
        destination_object,
        src_bucket,
        source_object,
        opts
      )
    else
      dest_bucket
      |> adapter!(opts).put_object_copy(
        destination_object,
        src_bucket,
        source_object,
        opts
      )
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec put_object(
    bucket :: bucket(),
    object :: object(),
    body :: body(),
    opts :: opts()
  ) :: t_res()
  def put_object(bucket, object, body, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_response(bucket, object, body, opts)
    else
      bucket
      |> adapter!(opts).put_object(object, body, opts)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec delete_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
  def delete_object(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_delete_object_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).delete_object(object, opts)
      |> handle_response()
    end
  end

  defp adapter!(opts) do
    opts[:storage_adapter] || Config.storage_adapter() || @default_adapter
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, %{code: _, message: _, details: _}} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, term()}`
    `{:error, %{code: term(), message: term(), details: term()}}`

    got:

    #{inspect(term, pretty: true)}
    """
  end

  if Mix.env() === :test do
    defdelegate sandbox_download_chunk_stream_response(bucket, object, chunk_size, opts),
      to: Uppy.StorageSandbox,
      as: :download_chunk_stream_response

    defdelegate sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts),
      to: Uppy.StorageSandbox,
      as: :get_chunk_response

    defdelegate sandbox_list_objects_response(bucket, prefix, opts),
      to: Uppy.StorageSandbox,
      as: :list_objects_response

    defdelegate sandbox_get_object_response(bucket, object, opts),
      to: Uppy.StorageSandbox,
      as: :get_object_response

    defdelegate sandbox_head_object_response(bucket, object, opts),
      to: Uppy.StorageSandbox,
      as: :head_object_response

    defdelegate sandbox_presigned_url_response(bucket, method, object, opts),
      to: Uppy.StorageSandbox,
      as: :presigned_url_response

    defdelegate sandbox_list_multipart_uploads_response(bucket, opts),
      to: Uppy.StorageSandbox,
      as: :list_multipart_uploads_response

    defdelegate sandbox_initiate_multipart_upload_response(bucket, object, opts),
      to: Uppy.StorageSandbox,
      as: :initiate_multipart_upload_response

    defdelegate sandbox_list_parts_response(
      bucket,
      object,
      upload_id,
      next_part_number_marker,
      opts
    ),
    to: Uppy.StorageSandbox,
    as: :list_parts_response

    defdelegate sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts),
      to: Uppy.StorageSandbox,
      as: :abort_multipart_upload_response

    defdelegate sandbox_complete_multipart_upload_response(
      bucket,
      object,
      upload_id,
      parts,
      opts
    ),
    to: Uppy.StorageSandbox,
    as: :complete_multipart_upload_response

    defdelegate sandbox_put_object_copy_response(
      dest_bucket,
      destination_object,
      src_bucket,
      source_object,
      opts
    ),
    to: Uppy.StorageSandbox,
    as: :put_object_copy_response

    defdelegate sandbox_put_object_response(bucket, object, body, opts),
      to: Uppy.StorageSandbox,
      as: :put_object_response

    defdelegate sandbox_delete_object_response(bucket, object, opts),
      to: Uppy.StorageSandbox,
      as: :delete_object_response

    defdelegate sandbox_disabled?, to: Uppy.StorageSandbox
  else
    defp sandbox_download_chunk_stream_response(bucket, object, chunk_size, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      chunk_size: #{inspect(chunk_size)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      start_byte: #{inspect(start_byte)}
      end_byte: #{inspect(end_byte)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_objects_response(bucket, prefix, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      prefix: #{prefix}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_get_object_response(bucket, object, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_head_object_response(bucket, object, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_presigned_url_response(bucket, method, object, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      method: #{inspect(method)}
      object: #{inspect(object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_multipart_uploads_response(bucket, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_initiate_multipart_upload_response(bucket, object, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_parts_response(bucket, object, upload_id, next_part_number_marker, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      next_part_number_marker: #{inspect(next_part_number_marker)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      parts: #{inspect(parts, pretty: true)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_put_object_copy_response(
           dest_bucket,
           destination_object,
           src_bucket,
           source_object,
           opts
         ) do
      raise """
      Cannot use StorageSandbox outside of test

      dest_bucket: #{inspect(dest_bucket)}
      destination_object: #{inspect(destination_object)}
      src_bucket: #{inspect(src_bucket)}
      source_object: #{inspect(source_object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_put_object_response(bucket, object, body, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      body: #{inspect(body)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_delete_object_response(bucket, object, opts) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      opts: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
