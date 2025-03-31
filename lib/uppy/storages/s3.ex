if Uppy.Utils.ensure_all_loaded?([ExAws, ExAws.S3]) do
  defmodule Uppy.Storages.S3 do
    @moduledoc """
    Amazon S3

    This module implements the `Uppy.Storage` behaviour.

    ## Getting started

    1. Add the dependencies to your `mix.exs` file:

    ```elixir
    # mix.exs
    defp deps do
      [
        {:ex_aws, "~> 2.1"},
        {:ex_aws_s3, "~> 2.0"},
        {:sweet_xml, "~> 0.6"}
      ]
    end
    ```

    2. Add the adapter to your `config.exs` file:

    ```elixir
    # config.exs
    config :uppy, storage_adapter: Uppy.Storages.S3
    ```
    """
    alias Uppy.Error
    alias Uppy.Storages.S3.Parser

    @type bucket :: Uppy.Storage.bucket()
    @type http_method :: Uppy.Storage.http_method()
    @type object :: Uppy.Storage.object()
    @type key :: Uppy.Storage.key()
    @type url :: Uppy.Storage.url()
    @type upload_id :: Uppy.Storage.upload_id()
    @type part_number :: Uppy.Storage.part_number()

    @type opts :: Uppy.Storage.opts()

    @type head_object_payload :: Uppy.Storage.head_object_payload()
    @type pre_sign_payload :: Uppy.Storage.pre_sign_payload()
    @type sign_part_payload :: Uppy.Storage.sign_part_payload()

    @behaviour Uppy.Storage

    @one_minute_seconds 60

    @default_opts [
      region: "us-west-1",
      http_client: Uppy.Storages.S3.HTTP
    ]

    def object_chunk_stream(bucket, object, chunk_size, opts) do
      opts = Keyword.merge(default_opts(), opts)

      with {:ok, metadata} <- head_object(bucket, object, opts) do
        {:ok, ExAws.S3.Download.chunk_stream(metadata.content_length, chunk_size)}
      end
    end

    def get_chunk(bucket, object, start_byte, end_byte, opts) do
      opts = Keyword.merge(default_opts(), opts)

      s3_opts =
        opts
        |> Keyword.get(:s3, [])
        |> Keyword.put(:range, "bytes=#{start_byte}-#{end_byte}")

      with {:ok, body} <-
             bucket
             |> ExAws.S3.get_object(object, s3_opts)
             |> ExAws.request(opts)
             |> deserialize_response() do
        {:ok, {start_byte, body}}
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_objects/3`.

    ### Examples

        iex> Uppy.Storages.S3.list_objects("your_bucket", "your/prefix")
    """
    def list_objects(bucket, prefix \\ nil, opts \\ []) do
      opts = Keyword.merge(default_opts(), opts)

      opts =
        if is_binary(prefix) do
          Keyword.put_new(opts, :prefix, prefix)
        else
          opts
        end

      bucket
      |> ExAws.S3.list_objects_v2(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.get_object/3`.

    ### Examples

        iex> Uppy.Storages.S3.get_object("your_bucket", "example_image.jpeg")
    """
    def get_object(bucket, object, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.get_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.head_object/3`.

    ### Examples

        iex> Uppy.Storages.S3.head_object("your_bucket", "example_image.jpeg")
    """
    @spec head_object(
            bucket :: bucket(),
            object :: object()
          ) :: {:ok, head_object_payload()} | {:error, term()}
    @spec head_object(
            bucket :: bucket(),
            object :: object(),
            opts :: keyword()
          ) :: {:ok, head_object_payload()} | {:error, term()}
    def head_object(bucket, object, opts \\ []) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.head_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_headers()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.sign_part/5`.

    ### Examples

        iex> Uppy.Storages.S3.sign_part("your_bucket", "example_image.jpeg", "upload_id", 1)
    """
    @spec sign_part(
            bucket :: bucket(),
            object :: object(),
            upload_id :: upload_id(),
            part_number :: part_number()
          ) :: {:ok, sign_part_payload()} | {:error, term()}
    @spec sign_part(
            bucket :: bucket(),
            object :: object(),
            upload_id :: upload_id(),
            part_number :: part_number(),
            opts :: keyword()
          ) :: {:ok, sign_part_payload()} | {:error, term()}
    def sign_part(bucket, object, upload_id, part_number, opts \\ []) do
      query_params = %{"uploadId" => upload_id, "partNumber" => part_number}

      opts =
        @default_opts
        |> Keyword.merge(opts)
        |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))

      case Keyword.get(opts, :http_method, :put) do
        :put ->
          pre_sign(bucket, :put, object, opts)

        :post ->
          pre_sign(bucket, :post, object, opts)

        term ->
          raise "Expected the option `:http_method` to be one of `[:put, :post]`, got: #{inspect(term)}"
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.pre_sign/4`.

    Returns a map with the following keys:

      * `:key` - The object string.
      * `:url` - The S3 pre-signed url string.
      * `:expires_at` - A DateTime struct that indicates when the url expires.

    ### Examples

        iex> Uppy.Storages.S3.pre_sign("your_bucket", :put, "example_image.jpeg")
    """
    @spec pre_sign(
            bucket :: bucket(),
            http_method :: http_method(),
            object :: object()
          ) :: {:ok, pre_sign_payload()} | {:error, term()}
    @spec pre_sign(
            bucket :: bucket(),
            http_method :: http_method(),
            object :: object(),
            opts :: keyword()
          ) :: {:ok, pre_sign_payload()} | {:error, term()}
    def pre_sign(bucket, http_method, object, opts \\ []) do
      opts = Keyword.merge(default_opts(), opts)

      expires_in = opts[:expires_in] || @one_minute_seconds

      with {:ok, url} <-
             :s3
             |> ExAws.Config.new(opts)
             |> ExAws.S3.presigned_url(http_method, bucket, object, opts)
             |> handle_response() do
        {:ok,
         %{
           key: object,
           url: url,
           expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
         }}
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_multipart_uploads/2`.
    """
    def list_multipart_uploads(bucket, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.list_multipart_uploads(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.create_multipart_upload/3`.
    """
    def create_multipart_upload(bucket, object, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.initiate_multipart_upload(object, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_parts/4`.
    """
    def list_parts(bucket, object, upload_id, opts) do
      opts = Keyword.merge(default_opts(), opts)

      s3_opts =
        if Keyword.has_key?(opts, :part_number_marker) do
          query_params = %{"part-number-marker" => opts[:part_number_marker]}

          opts
          |> Keyword.delete(:part_number_marker)
          |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))
        else
          Keyword.take(opts, [:query_params])
        end

      bucket
      |> ExAws.S3.list_parts(object, upload_id, s3_opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.abort_multipart_upload/4`.
    """
    def abort_multipart_upload(bucket, object, upload_id, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.abort_multipart_upload(object, upload_id)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.complete_multipart_upload/5`.
    """
    def complete_multipart_upload(bucket, object, upload_id, parts, opts) do
      opts = Keyword.merge(default_opts(), opts)

      res =
        bucket
        |> ExAws.S3.complete_multipart_upload(object, upload_id, parts)
        |> ExAws.request(opts)
        |> deserialize_response()

      case res do
        {:ok, _} -> head_object(bucket, object, opts)
        {:error, %{code: :not_found}} -> head_object(bucket, object, opts)
        {:error, _} = e -> e
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.put_object_copy/5`.
    """
    def put_object_copy(dest_bucket, destination_object, src_bucket, source_object, opts) do
      opts = Keyword.merge(default_opts(), opts)

      dest_bucket
      |> ExAws.S3.put_object_copy(destination_object, src_bucket, source_object, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.put_object/4`.
    """
    def put_object(bucket, object, body, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.put_object(object, body, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.delete_object/3`.
    """
    def delete_object(bucket, object, opts) do
      opts = Keyword.merge(default_opts(), opts)

      bucket
      |> ExAws.S3.delete_object(object, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    defp default_opts do
      Keyword.merge(@default_opts, Uppy.Config.module_config(__MODULE__) || [])
    end

    defp deserialize_response({:ok, %{body: %{contents: contents} = body}}) do
      {:ok, Map.merge(body, %{
        key_count: String.to_integer(body.key_count),
        max_keys: String.to_integer(body.max_keys),
        is_truncated: body.is_truncated in ["true", true],
        contents: Enum.map(contents, fn item ->
          Map.merge(item, %{
            e_tag: remove_quotations(item.e_tag),
            size: String.to_integer(item.size),
            last_modified: item.last_modified |> DateTime.from_iso8601() |> elem(1)
          })
        end)
     })}
    end

    defp deserialize_response({:ok, %{body: %{parts: parts}}}) do
      {:ok,
       Enum.map(parts, fn part ->
         %{
           e_tag: remove_quotations(part.etag),
           size: String.to_integer(part.size),
           part_number: String.to_integer(part.part_number)
         }
       end)}
    end

    defp deserialize_response({:ok, %{body: body}}), do: {:ok, body}

    defp deserialize_response({:error, _} = e), do: handle_response(e)

    defp deserialize_headers({:ok, %{headers: headers}}) when is_list(headers) do
      deserialize_headers({:ok, %{headers: Map.new(headers)}})
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _, "last-modified" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         last_modified: Parser.date_time_from_rfc7231!(headers["last-modified"]),
         content_type: headers["content-type"],
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: headers}}) do
      {:ok, headers}
    end

    defp deserialize_headers({:error, _} = e), do: handle_response(e)

    defp handle_response({:ok, _} = res), do: res

    defp handle_response({:error, msg}) when is_binary(msg) do
      if msg =~ "there's nothing to see here" do
        {:error, Error.call(:not_found, "resource not found.", %{error: msg})}
      else
        {:error, Error.call(:service_unavailable, "storage service unavailable.", %{error: msg})}
      end
    end

    defp remove_quotations(string) do
      String.replace(string, "\"", "")
    end
  end
end
