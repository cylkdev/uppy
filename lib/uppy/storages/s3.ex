if Uppy.Utils.ensure_all_loaded?([ExAws, ExAws.S3]) do
  defmodule Uppy.Storages.S3 do
    @moduledoc """
    Implements the `Uppy.Storage` behaviour.
    """
    alias Uppy.{Error, Utils}

    @behaviour Uppy.Storage

    @default_opts [http_client: Uppy.Storages.S3.HTTP]

    @one_minute_seconds 60

    def download_chunk_stream(bucket, object, chunk_size, opts) do
      opts = Keyword.merge(@default_opts, opts)

      with {:ok, metadata} <- head_object(bucket, object, opts) do
        {:ok, ExAws.S3.Download.chunk_stream(metadata.content_length, chunk_size)}
      end
    end

    def get_chunk(bucket, object, start_byte, end_byte, opts) do
      opts = Keyword.merge(@default_opts, opts)

      request_opts = Keyword.put(opts, :range, "bytes=#{start_byte}-#{end_byte}")

      with {:ok, body} <-
        bucket
        |> ExAws.S3.get_object(object, request_opts)
        |> ExAws.request(opts)
        |> deserialize_response() do
        {:ok, {start_byte, body}}
      end
    end

    def get_chunk!(bucket, object, start_byte, end_byte, opts) do
      {:ok, chunk} = get_chunk(bucket, object, start_byte, end_byte, opts)

      chunk
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_objects/3`.
    """
    def list_objects(bucket, prefix \\ nil, opts) do
      opts = Keyword.merge(@default_opts, opts)

      opts =
        if prefix in [nil, ""] do
          Keyword.delete(opts, :prefix)
        else
          Keyword.put(opts, :prefix, prefix)
        end

      bucket
      |> ExAws.S3.list_objects_v2(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.get_object/3`.
    """
    def get_object(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.get_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.head_object/3`.
    """
    def head_object(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.head_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_headers()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.presigned_url/4`.
    """
    def presigned_url(bucket, http_method, object, opts) do
      opts =
        @default_opts
        |> Keyword.merge(opts)
        |> s3_accelerate(http_method)

      opts = Keyword.put_new(opts, :expires_in, @one_minute_seconds)

      expires_in = opts[:expires_in]

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

    defp s3_accelerate(opts, http_method) do
      if http_method in [:post, :put] do
        s3_accelerate = opts[:s3_accelerate] === true

        Keyword.put_new(opts, :s3_accelerate, s3_accelerate)
      else
        opts
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_multipart_uploads/2`.
    """
    def list_multipart_uploads(bucket, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.list_multipart_uploads(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.initiate_multipart_upload/3`.
    """
    def initiate_multipart_upload(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.initiate_multipart_upload(object)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_parts/4`.
    """
    def list_parts(bucket, object, upload_id, next_part_number_marker \\ nil, opts) do
      opts = Keyword.merge(@default_opts, opts)

      opts =
        if next_part_number_marker do
          query_params = %{"part-number-marker" => next_part_number_marker}

          Keyword.update(opts, :query_params, query_params, &Map.merge(&1, query_params))
        else
          opts
        end

      bucket
      |> ExAws.S3.list_parts(object, upload_id, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.abort_multipart_upload/4`.
    """
    def abort_multipart_upload(bucket, object, upload_id, opts) do
      opts = Keyword.merge(@default_opts, opts)

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
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.complete_multipart_upload(object, upload_id, parts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.put_object_copy/5`.
    """
    def put_object_copy(dest_bucket, destination_object, src_bucket, source_object, opts) do
      opts = Keyword.merge(@default_opts, opts)

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
      opts = Keyword.merge(@default_opts, opts)

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
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.delete_object(object, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    defp deserialize_response({:ok, %{body: %{contents: contents}}}) do
      {:ok,
       Enum.map(contents, fn content ->
         %{
           content
           | e_tag: remove_quotations(content.e_tag),
             size: String.to_integer(content.size),
             last_modified: content.last_modified |> DateTime.from_iso8601() |> elem(1)
         }
       end)}
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
         last_modified: Utils.date_time_from_rfc7231!(headers["last-modified"]),
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
