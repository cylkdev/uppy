defmodule Uppy.Storage do
  alias Uppy.Config

  @type t_res :: Uppy.Adapter.Storage.t_res()

  @type adapter :: Uppy.Adapter.Storage.adapter()
  @type bucket :: Uppy.Adapter.Storage.bucket()
  @type prefix :: Uppy.Adapter.Storage.prefix()
  @type object :: Uppy.Adapter.Storage.object()
  @type body :: Uppy.Adapter.Storage.body()
  @type e_tag :: Uppy.Adapter.Storage.e_tag()
  @type options :: Uppy.Adapter.Storage.options()
  @type http_method :: Uppy.Adapter.Storage.http_method()

  @type part_number :: Uppy.Adapter.Storage.part_number()
  @type upload_id :: Uppy.Adapter.Storage.upload_id()
  @type marker :: Uppy.Adapter.Storage.marker()
  @type part :: Uppy.Adapter.Storage.part()
  @type parts :: Uppy.Adapter.Storage.parts()

  @default_storage_adapter Uppy.Storages.S3

  @default_options [
    storage: [
      sandbox: Mix.env() === :test,
      http_method: :put
    ]
  ]

  def download_chunk_stream(bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    bucket
    |> adapter!(options).download_chunk_stream(object, options)
    |> handle_response()
  end

  def get_chunk(bucket, object, start_byte, end_byte, options) do
    options = Keyword.merge(@default_options, options)

    bucket
    |> adapter!(options).get_chunk(object, start_byte, end_byte, options)
    |> handle_response()
  end

  @spec list_objects(
          bucket :: bucket(),
          prefix :: prefix(),
          options :: options()
        ) :: t_res()
  def list_objects(bucket, prefix, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_objects_response(bucket, prefix, options)
    else
      bucket
      |> adapter!(options).list_objects(prefix, options)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec get_object(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def get_object(bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_object_response(bucket, object, options)
    else
      bucket
      |> adapter!(options).get_object(object, options)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec head_object(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def head_object(bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_head_object_response(bucket, object, options)
    else
      bucket
      |> adapter!(options).head_object(object, options)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec presigned_download(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_download(bucket, object, options \\ []) do
    options = Keyword.merge(@default_options, options)

    presigned_url(bucket, :get, object, options)
  end

  @doc """
  ...
  """
  @spec presigned_part_upload(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          part_number :: part_number(),
          options :: options()
        ) :: t_res()
  def presigned_part_upload(
        bucket,
        object,
        upload_id,
        part_number,
        options \\ []
      ) do
    query_params = %{
      "uploadId" => upload_id,
      "partNumber" => part_number
    }

    options =
      @default_options
      |> Keyword.merge(options)
      |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))

    presigned_upload(bucket, object, options)
  end

  @doc """
  ...
  """
  @spec presigned_upload(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_upload(bucket, object, options \\ []) do
    options = Keyword.merge(@default_options, options)

    http_method = upload_http_method!(options)

    presigned_url(bucket, http_method, object, options)
  end

  defp upload_http_method!(options) do
    case options[:storage][:http_method] do
      nil -> :put
      :post -> :post
      :put -> :put
      term -> raise ArgumentError, "Expected `:post` or `:put`, got: #{inspect(term)}"
    end
  end

  @doc """
  ...
  """
  @spec presigned_url(
          bucket :: bucket(),
          http_method :: http_method(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_url(bucket, http_method, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_presigned_url_response(bucket, http_method, object, options)
    else
      bucket
      |> adapter!(options).presigned_url(http_method, object, options)
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

    {:ok, %{url: String.t(), expires_at: DateTime.t()}}
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
  @spec list_multipart_uploads(
          bucket :: bucket(),
          options :: options()
        ) :: t_res()
  def list_multipart_uploads(bucket, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_multipart_uploads_response(bucket, options)
    else
      bucket
      |> adapter!(options).list_multipart_uploads(options)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec initiate_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def initiate_multipart_upload(bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_initiate_multipart_upload_response(bucket, object, options)
    else
      bucket
      |> adapter!(options).initiate_multipart_upload(object, options)
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
          options :: options()
        ) :: t_res()
  def list_parts(bucket, object, upload_id, next_part_number_marker, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_parts_response(bucket, object, upload_id, next_part_number_marker, options)
    else
      bucket
      |> adapter!(options).list_parts(object, upload_id, next_part_number_marker, options)
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
          options :: options()
        ) :: t_res()
  def abort_multipart_upload(bucket, object, upload_id, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_abort_multipart_upload_response(bucket, object, upload_id, options)
    else
      bucket
      |> adapter!(options).abort_multipart_upload(object, upload_id, options)
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
          options :: options()
        ) :: t_res()
  def complete_multipart_upload(bucket, object, upload_id, parts, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, options)
    else
      bucket
      |> adapter!(options).complete_multipart_upload(object, upload_id, parts, options)
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
          options :: options()
        ) :: t_res()
  def put_object_copy(
        dest_bucket,
        destination_object,
        src_bucket,
        source_object,
        options
      ) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_copy_response(
        dest_bucket,
        destination_object,
        src_bucket,
        source_object,
        options
      )
    else
      dest_bucket
      |> adapter!(options).put_object_copy(
        destination_object,
        src_bucket,
        source_object,
        options
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
          options :: options()
        ) :: t_res()
  def put_object(bucket, object, body, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_response(bucket, object, body, options)
    else
      bucket
      |> adapter!(options).put_object(object, body, options)
      |> handle_response()
    end
  end

  @doc """
  ...
  """
  @spec delete_object(
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def delete_object(bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_delete_object_response(bucket, object, options)
    else
      bucket
      |> adapter!(options).delete_object(object, options)
      |> handle_response()
    end
  end

  defp adapter!(options) do
    Keyword.get(options, :storage_adapter, Config.storage_adapter()) || @default_storage_adapter
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
    defdelegate sandbox_list_objects_response(bucket, prefix, options),
      to: Uppy.Support.StorageSandbox,
      as: :list_objects_response

    defdelegate sandbox_get_object_response(bucket, object, options),
      to: Uppy.Support.StorageSandbox,
      as: :get_object_response

    defdelegate sandbox_head_object_response(bucket, object, options),
      to: Uppy.Support.StorageSandbox,
      as: :head_object_response

    defdelegate sandbox_presigned_url_response(bucket, method, object, options),
      to: Uppy.Support.StorageSandbox,
      as: :presigned_url_response

    defdelegate sandbox_list_multipart_uploads_response(bucket, options),
      to: Uppy.Support.StorageSandbox,
      as: :list_multipart_uploads_response

    defdelegate sandbox_initiate_multipart_upload_response(bucket, object, options),
      to: Uppy.Support.StorageSandbox,
      as: :initiate_multipart_upload_response

    defdelegate sandbox_list_parts_response(
                  bucket,
                  object,
                  upload_id,
                  next_part_number_marker,
                  options
                ),
                to: Uppy.Support.StorageSandbox,
                as: :list_parts_response

    defdelegate sandbox_abort_multipart_upload_response(bucket, object, upload_id, options),
      to: Uppy.Support.StorageSandbox,
      as: :abort_multipart_upload_response

    defdelegate sandbox_complete_multipart_upload_response(
                  bucket,
                  object,
                  upload_id,
                  parts,
                  options
                ),
                to: Uppy.Support.StorageSandbox,
                as: :complete_multipart_upload_response

    defdelegate sandbox_put_object_copy_response(
                  dest_bucket,
                  destination_object,
                  src_bucket,
                  source_object,
                  options
                ),
                to: Uppy.Support.StorageSandbox,
                as: :put_object_copy_response

    defdelegate sandbox_put_object_response(bucket, object, body, options),
      to: Uppy.Support.StorageSandbox,
      as: :put_object_response

    defdelegate sandbox_delete_object_response(bucket, object, options),
      to: Uppy.Support.StorageSandbox,
      as: :delete_object_response

    defdelegate sandbox_disabled?, to: Uppy.Support.StorageSandbox
  else
    defp sandbox_list_objects_response(bucket, prefix, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      prefix: #{prefix}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_get_object_response(bucket, object, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_head_object_response(bucket, object, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_presigned_url_response(bucket, method, object, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      method: #{inspect(method)}
      object: #{inspect(object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_list_multipart_uploads_response(bucket, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_initiate_multipart_upload_response(bucket, object, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_list_parts_response(bucket, object, upload_id, next_part_number_marker, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      next_part_number_marker: #{inspect(next_part_number_marker)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_abort_multipart_upload_response(bucket, object, upload_id, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      parts: #{inspect(parts, pretty: true)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_put_object_copy_response(
           dest_bucket,
           destination_object,
           src_bucket,
           source_object,
           options
         ) do
      raise """
      Cannot use StorageSandbox outside of test

      dest_bucket: #{inspect(dest_bucket)}
      destination_object: #{inspect(destination_object)}
      src_bucket: #{inspect(src_bucket)}
      source_object: #{inspect(source_object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_put_object_response(bucket, object, body, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      body: #{inspect(body)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_delete_object_response(bucket, object, options) do
      raise """
      Cannot use StorageSandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(options, pretty: true)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
