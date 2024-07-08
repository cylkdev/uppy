defmodule Uppy.Storage do
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
  @type maybe_marker :: Uppy.Adapter.Storage.maybe_marker()
  @type part :: Uppy.Adapter.Storage.part()
  @type parts :: Uppy.Adapter.Storage.parts()

  @default_options [
    storage: [
      sandbox: Mix.env() === :test,
      presigned_upload: [http_method: :put],
      presigned_part_upload: [http_method: :put]
    ]
  ]

  @spec list_objects(
          adapter :: adapter(),
          bucket :: bucket(),
          prefix :: prefix(),
          options :: options()
        ) :: t_res()
  def list_objects(adapter, bucket, prefix, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_objects_response(bucket, prefix, options)
    else
      bucket
      |> adapter.list_objects(prefix, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec get_object(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def get_object(adapter, bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_object_response(bucket, object, options)
    else
      bucket
      |> adapter.get_object(object, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec head_object(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def head_object(adapter, bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_head_object_response(bucket, object, options)
    else
      bucket
      |> adapter.head_object(object, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec presigned_download(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_download(adapter, bucket, object, options \\ []) do
    options = Keyword.merge(@default_options, options)

    presigned_url(adapter, bucket, :get, object, options)
  end

  @doc """
  ...
  """
  @spec presigned_part_upload(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          part_number :: part_number(),
          options :: options()
        ) :: t_res()
  def presigned_part_upload(
        adapter,
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

    http_method = upload_http_method(options, :presigned_part_upload)

    presigned_url(adapter, bucket, http_method, object, options)
  end

  @doc """
  ...
  """
  @spec presigned_upload(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_upload(adapter, bucket, object, options \\ []) do
    options = Keyword.merge(@default_options, options)

    http_method = upload_http_method(options, :presigned_upload)

    presigned_url(adapter, bucket, http_method, object, options)
  end

  defp upload_http_method(options, action) do
    case options[:storage][action][:http_method] do
      :post -> :post
      :put -> :put
      term -> raise ArgumentError, "expected `:put` or `:put`, got: #{inspect(term)}"
    end
  end

  @doc """
  ...
  """
  @spec presigned_url(
          adapter :: adapter(),
          bucket :: bucket(),
          http_method :: http_method(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def presigned_url(adapter, bucket, http_method, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_presigned_url_response(bucket, http_method, object, options)
    else
      bucket
      |> adapter.presigned_url(http_method, object, options)
      |> ensure_status_tuple!()
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
          adapter :: adapter(),
          bucket :: bucket(),
          options :: options()
        ) :: t_res()
  def list_multipart_uploads(adapter, bucket, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_multipart_uploads_response(bucket, options)
    else
      bucket
      |> adapter.list_multipart_uploads(options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec initiate_multipart_upload(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def initiate_multipart_upload(adapter, bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_initiate_multipart_upload_response(bucket, object, options)
    else
      bucket
      |> adapter.initiate_multipart_upload(object, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec list_parts(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          next_part_number_marker :: maybe_marker(),
          options :: options()
        ) :: t_res()
  def list_parts(adapter, bucket, object, upload_id, next_part_number_marker, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_parts_response(bucket, object, upload_id, next_part_number_marker, options)
    else
      bucket
      |> adapter.list_parts(object, upload_id, next_part_number_marker, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec abort_multipart_upload(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          options :: options()
        ) :: t_res()
  def abort_multipart_upload(adapter, bucket, object, upload_id, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_abort_multipart_upload_response(bucket, object, upload_id, options)
    else
      bucket
      |> adapter.abort_multipart_upload(object, upload_id, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec confirm_multipart_upload(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          parts :: parts(),
          options :: options()
        ) :: t_res()
  def confirm_multipart_upload(adapter, bucket, object, upload_id, parts, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_confirm_multipart_upload_response(bucket, object, upload_id, parts, options)
    else
      bucket
      |> adapter.confirm_multipart_upload(object, upload_id, parts, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec put_object_copy(
          adapter :: adapter(),
          dest_bucket :: bucket(),
          dest_object :: object(),
          src_bucket :: bucket(),
          src_object :: object(),
          options :: options()
        ) :: t_res()
  def put_object_copy(adapter, dest_bucket, dest_object, src_bucket, src_object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_copy_response(dest_bucket, dest_object, src_bucket, src_object, options)
    else
      dest_bucket
      |> adapter.put_object_copy(dest_object, src_bucket, src_object, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec put_object(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          body :: body(),
          options :: options()
        ) :: t_res()
  def put_object(adapter, bucket, object, body, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_put_object_response(bucket, object, body, options)
    else
      bucket
      |> adapter.put_object(object, body, options)
      |> ensure_status_tuple!()
    end
  end

  @doc """
  ...
  """
  @spec delete_object(
          adapter :: adapter(),
          bucket :: bucket(),
          object :: object(),
          options :: options()
        ) :: t_res()
  def delete_object(adapter, bucket, object, options) do
    options = Keyword.merge(@default_options, options)

    sandbox? = options[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_delete_object_response(bucket, object, options)
    else
      bucket
      |> adapter.delete_object(object, options)
      |> ensure_status_tuple!()
    end
  end

  defp ensure_status_tuple!({:ok, _} = ok), do: ok
  defp ensure_status_tuple!({:error, _} = error), do: error

  defp ensure_status_tuple!(term) do
    raise """
    Expected one of:

    {:ok, term()}
    {:error, term()}

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

    defdelegate sandbox_confirm_multipart_upload_response(
                  bucket,
                  object,
                  upload_id,
                  parts,
                  options
                ),
                to: Uppy.Support.StorageSandbox,
                as: :confirm_multipart_upload_response

    defdelegate sandbox_put_object_copy_response(
                  dest_bucket,
                  dest_object,
                  src_bucket,
                  src_object,
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

    defp sandbox_confirm_multipart_upload_response(bucket, object, upload_id, parts, options) do
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
           dest_object,
           src_bucket,
           src_object,
           options
         ) do
      raise """
      Cannot use StorageSandbox outside of test

      dest_bucket: #{inspect(dest_bucket)}
      dest_object: #{inspect(dest_object)}
      src_bucket: #{inspect(src_bucket)}
      src_object: #{inspect(src_object)}
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
