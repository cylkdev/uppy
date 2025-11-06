defmodule Uppy.Core do
  @moduledoc false

  @primary_keys [:id, :key, :unique_identifier]
  @pending :pending
  @completed :completed
  @aborted :aborted

  def delete_upload(bucket, %schema_module{} = schema_struct, _params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3

    with {:ok, _} <- storage.delete_object(bucket, schema_struct.key, opts),
         {:ok, schema_struct} <-
           schema_struct
           |> schema_module.changeset(%{})
           |> database.delete(opts) do
      {:ok, schema_struct}
    else
      {:error, %{code: :not_found}} ->
        schema_struct
        |> schema_module.changeset(%{})
        |> database.delete(opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      delete_upload(bucket, schema_struct, Map.drop(params, @primary_keys), opts)
    end
  end

  @doc group: "Upload API"
  @doc """
  Promote a upload.

  ### Examples

      iex> Uppy.Core.promote_upload("uppy-sandbox", "dest/5mb.txt", Uppy.Schemas.Upload, %{key: "temp/5mb.txt"}, %{}, [])

      iex> Uppy.Core.promote_upload("uppy-sandbox", "dest/m/5mb.txt", Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, %{}, [])
  """
  def promote_upload(bucket, destination, %src_schema_module{} = parent, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3

    dest_bucket = opts[:destination][:bucket] || bucket
    dest_schema_module = opts[:destination][:schema_module] || src_schema_module
    unique_identifier = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    label =
      params[:label] ||
        Map.get(parent, :label) ||
        to_string(dest_schema_module)

    dest_key =
      case destination do
        dest_key when is_binary(dest_key) -> dest_key
        fun when is_function(fun) -> fun.(parent, params)
      end

    with {:ok, _} <- storage.copy_object(dest_bucket, dest_key, bucket, parent.key, opts),
         {:ok, metadata} <- storage.head_object(dest_bucket, dest_key, opts),
         {:ok, dest_schema_struct} <-
           database.create(
             dest_schema_module,
             Map.merge(params, %{
               state: @completed,
               bucket: dest_bucket,
               label: label,
               promoted: true,
               filename: params[:filename] || parent.filename,
               unique_identifier: params[:unique_identifier] || unique_identifier,
               key: dest_key,
               content_length: metadata.content_length,
               content_type: metadata.content_type,
               last_modified: metadata.last_modified,
               etag: metadata.etag,
               parent_id: parent.id
             }),
             opts
           ) do
      {:ok,
       %{
         source: parent,
         destination: dest_schema_struct
       }}
    end
  end

  def promote_upload(bucket, dest_key, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      promote_upload(bucket, dest_key, schema_struct, Map.drop(params, @primary_keys), opts)
    end
  end

  @doc group: "Upload API"
  @doc """
  Complete a upload.

  ### Examples

      iex> Uppy.Core.complete_upload("uppy-sandbox", "temp/5mb.txt", Uppy.Schemas.Upload, %{}, [])
  """
  def complete_upload(bucket, %schema_module{} = schema_struct, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    label =
      params[:label] ||
        Map.get(schema_struct, :label) ||
        module_to_name(schema_module)

    cond do
      not is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("malformed request", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, metadata} <- storage.head_object(bucket, schema_struct.key, opts),
             {:ok, schema_struct} <-
               database.update(
                 schema_module,
                 schema_struct,
                 Map.merge(params, %{
                   state: @completed,
                   bucket: params[:bucket] || schema_struct.bucket,
                   label: params[:label] || label,
                   content_length: metadata.content_length,
                   content_type: metadata.content_type,
                   last_modified: metadata.last_modified,
                   etag: metadata.etag
                 }),
                 opts
               ) do
          {:ok, schema_struct}
        end
    end
  end

  def complete_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      complete_upload(bucket, schema_struct, params, opts)
    end
  end

  @doc group: "Upload API"
  @doc """
  Abort a upload.
  """
  def abort_upload(bucket, %schema_module{} = schema_struct, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    cond do
      not is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("malformed request", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        case storage.head_object(bucket, schema_struct.key, opts) do
          {:ok, metadata} ->
            {:error,
             ErrorMessage.bad_request("upload complete", %{
               data: schema_struct,
               metadata: metadata
             })}

          {:error, _} ->
            with {:ok, schema_struct} <-
                   database.update(
                     schema_module,
                     schema_struct,
                     Map.put(params, :state, @aborted),
                     opts
                   ) do
              {:ok, schema_struct}
            end
        end
    end
  end

  def abort_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      abort_upload(bucket, schema_struct, Map.drop(params, @primary_keys), opts)
    end
  end

  @doc group: "Upload API"
  @doc """
  Pre-sign a upload.

  ### Examples

  ```elixir
  Uppy.Core.pre_sign_upload("uppy-sandbox", "temp/5mb.txt", Uppy.Schemas.Upload, %{}, [])

  content = :crypto.strong_rand_bytes(5 * 1024 * 1024) |> Base.encode64() |> binary_part(0, 5 * 1024 * 1024)
  File.write!("5mb.txt", content)

  curl -X PUT -T "5mb.txt" "http://s3.localhost.localstack.cloud:4566/uppy-sandbox/temp/5mb.txt?X-Amz-Algorithm=AWS4-HMAC-SSHA256&X-Amz-Credential=test%2F20251106%2Fus-west-1%2Fs3%2Faws4_request&X-Amz-Date=20251106T071902Z&X-Amz-Expires=60&X-Amz-SignedHeaders=host&X-Amz-Signature=7e6b7f65a8773244b4955d14405944e48651cc36c0804e865366f3b1f36dfebd"
  ```
  """
  def pre_sign_upload(bucket, %_{} = schema_struct, _params, opts) do
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    cond do
      not is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("malformed request", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, pre_signed_upload} <- storage.pre_sign(bucket, schema_struct.key, opts) do
          {:ok,
           %{
             pre_signed_url: pre_signed_upload,
             data: schema_struct
           }}
        end
    end
  end

  def pre_sign_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      pre_sign_upload(bucket, schema_struct, Map.drop(params, @primary_keys), opts)
    end
  end

  @doc group: "Upload API"
  @doc """
  Create a upload.

  ### Examples


  Uppy.Repo.start_link()
  Uppy.Core.create_upload("uppy-sandbox", "temp/5mb.txt", Uppy.Schemas.Upload, %{}, [])
  """
  def create_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <-
           database.create(
             schema_module,
             Map.merge(params, %{
               state: @pending,
               label: params[:label] || module_to_name(schema_module),
               bucket: bucket,
               key: params.key,
               filename: params[:filename] || Path.basename(params.key)
             }),
             opts
           ) do
      {:ok, schema_struct}
    end
  end

  @doc group: "Multipart Upload API"
  @doc """
  Complete a multipart upload.

  ### Examples

      iex> Uppy.Core.complete_multipart_upload("uppy-sandbox", [%{etag: "6a94c63c450686db4da43803c1eaf4cf", part_number: 1}], Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, [])
  """
  def complete_multipart_upload(
        bucket,
        parts,
        %schema_module{} = schema_struct,
        params,
        opts
      ) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    label =
      params[:label] ||
        Map.get(schema_struct, :label) ||
        module_to_name(schema_module)

    parts =
      Enum.map(parts, fn
        {part_number, etag} -> {part_number, etag}
        item -> {item.part_number, item.etag}
      end)

    cond do
      is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.not_found("upload not found", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, _} <-
               storage.complete_multipart_upload(
                 bucket,
                 schema_struct.key,
                 schema_struct.upload_id,
                 parts,
                 opts
               ),
             {:ok, metadata} <- storage.head_object(bucket, schema_struct.key, opts),
             {:ok, schema_struct} <-
               database.update(
                 schema_module,
                 schema_struct,
                 Map.merge(params, %{
                   state: @completed,
                   bucket: params[:bucket] || schema_struct.bucket,
                   label: params[:label] || label,
                   content_length: metadata.content_length,
                   content_type: metadata.content_type,
                   last_modified: metadata.last_modified,
                   etag: metadata.etag
                 }),
                 opts
               ) do
          {:ok, schema_struct}
        else
          {:error, %{code: :not_found}} ->
            with {:ok, metadata} <- storage.head_object(bucket, schema_struct.key, opts),
                 {:ok, schema_struct} <-
                   database.update(
                     schema_module,
                     schema_struct,
                     Map.merge(params, %{
                       state: @completed,
                       bucket: params[:bucket] || schema_struct.bucket,
                       label: params[:label] || label,
                       content_length: metadata.content_length,
                       content_type: metadata.content_type,
                       last_modified: metadata.last_modified,
                       etag: metadata.etag
                     }),
                     opts
                   ) do
              {:ok, schema_struct}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def complete_multipart_upload(bucket, parts, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      complete_multipart_upload(
        bucket,
        parts,
        schema_struct,
        Map.drop(params, @primary_keys),
        opts
      )
    end
  end

  @doc group: "Multipart Upload API"
  @doc """
  Find parts of a multipart upload.

  ### Examples

      iex> Uppy.Core.find_parts("uppy-sandbox", Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, [])
  """
  def find_parts(bucket, %_{} = schema_struct, _params, opts) do
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    cond do
      is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("upload_id not found", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload not in progress", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, parts} <-
               storage.list_parts(bucket, schema_struct.key, schema_struct.upload_id, opts) do
          {:ok,
           %{
             data: schema_struct,
             parts: parts
           }}
        end
    end
  end

  def find_parts(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      find_parts(bucket, schema_struct, params, opts)
    end
  end

  @doc group: "Multipart Upload API"
  @doc """
  Sign a part of a multipart upload.

  ### Examples

  ```elixir
  Uppy.Core.pre_sign_upload_part("uppy-sandbox", 1, Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, [])

  content = :crypto.strong_rand_bytes(5 * 1024 * 1024) |> Base.encode64() |> binary_part(0, 5 * 1024 * 1024)
  File.write!("5mb.txt", content)

  curl -X PUT -T "5mb.txt" "http://s3.localhost.localstack.cloud:4566/uppy-sandbox/temp/m/5mb.txt?partNumber=1&uploadId=Obsu-Z1yFuWweBEDM7_wYwuX4xycJOCIV8idb92kfuznX8ZtFMNSsu23qQiIZowcOK4WIfkcVQlaB2po0RR8sUGT8BypBG1VcUx9k1esewq8QqlknCObiOdkpU5pxTIr&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test%2F20251106%2Fus-west-1%2Fs3%2Faws4_request&X-Amz-Date=20251106T162138Z&X-Amz-Expires=60&X-Amz-SignedHeaders=host&X-Amz-Signature=a9f2e449d19480652c3b31da8362740dc6bb0cfbfa148b26ecbf4a6a34cd2568"
  ```
  """
  def pre_sign_upload_part(bucket, part_number, %_{} = schema_struct, _params, opts) do
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    cond do
      is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("upload_id not found", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, pre_signed_part} <-
               storage.pre_sign_part(
                 bucket,
                 schema_struct.key,
                 schema_struct.upload_id,
                 part_number,
                 opts
               ) do
          {:ok,
           %{
             pre_signed_url: pre_signed_part,
             data: schema_struct
           }}
        end
    end
  end

  def pre_sign_upload_part(bucket, part_number, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      pre_sign_upload_part(
        bucket,
        part_number,
        schema_struct,
        Map.drop(params, @primary_keys),
        opts
      )
    end
  end

  @doc group: "Multipart Upload API"
  @doc """
  Abort a multipart upload.

  ### Examples

      iex> Uppy.Core.abort_multipart_upload("uppy-sandbox", Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, [])
  """
  def abort_multipart_upload(bucket, %schema_module{} = schema_struct, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3
    force? = Keyword.get(opts, :force, false)

    cond do
      is_nil(schema_struct.upload_id) ->
        {:error, ErrorMessage.bad_request("malformed request", %{data: schema_struct})}

      not force? and not is_nil(schema_struct.etag) ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      not force? and schema_struct.promoted ->
        {:error, ErrorMessage.bad_request("upload completed", %{data: schema_struct})}

      schema_struct.state === @aborted ->
        {:error, ErrorMessage.bad_request("upload aborted", %{data: schema_struct})}

      true ->
        with {:ok, _} <-
               storage.abort_multipart_upload(
                 bucket,
                 schema_struct.key,
                 schema_struct.upload_id,
                 opts
               ),
             {:ok, schema_struct} <-
               database.update(
                 schema_module,
                 schema_struct,
                 Map.put(params, :aborted, true),
                 opts
               ) do
          {:ok, schema_struct}
        else
          {:error, %{code: :not_found}} ->
            case storage.head_object(bucket, schema_struct.key, opts) do
              {:ok, metadata} ->
                {:error,
                 ErrorMessage.bad_request("upload completed", %{
                   data: schema_struct,
                   metadata: metadata
                 })}

              {:error, _} ->
                with {:ok, schema_struct} <-
                       database.update(
                         schema_module,
                         schema_struct,
                         Map.put(params, :aborted, true),
                         opts
                       ) do
                  {:ok, schema_struct}
                end
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def abort_multipart_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions

    with {:ok, schema_struct} <- database.find(schema_module, params, opts) do
      abort_multipart_upload(bucket, schema_struct, Map.drop(params, @primary_keys), opts)
    end
  end

  @doc group: "Multipart Upload API"
  @doc """
  Create a multipart upload.

  ### Examples

  Uppy.Repo.start_link()
  Oban.start_link([name: Uppy.Endpoint.Schedulers.Oban, repo: Uppy.Repo, queues: [uploads: 5]])
  Uppy.Core.create_multipart_upload("uppy-sandbox", Uppy.Schemas.Upload, %{key: "temp/m/5mb.txt"}, [])
  """
  def create_multipart_upload(bucket, schema_module, params, opts) do
    database = opts[:database_adapter] || EctoShorts.Actions
    storage = opts[:storage_adapter] || CloudCache.Adapters.S3

    with {:ok, mpu} <- storage.create_multipart_upload(bucket, params.key, opts),
         {:ok, schema_struct} <-
           database.create(
             schema_module,
             Map.merge(params, %{
               state: @pending,
               label: params[:label] || module_to_name(schema_module),
               bucket: bucket,
               key: params.key,
               upload_id: mpu.upload_id,
               filename: params[:filename] || Path.basename(params.key)
             }),
             opts
           ) do
      {:ok, schema_struct}
    end
  end

  defp module_to_name(module) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
    end
end
