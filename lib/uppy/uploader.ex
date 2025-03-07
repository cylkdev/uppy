defmodule Uppy.Uploader do
  @moduledoc false

  alias Uppy.{
    Core,
    DBAction,
    Uploader.Engine
  }

  def __uploader__(adapter) do
    %{
      bucket: adapter.bucket(),
      query: adapter.query(),
      path_builder: adapter.path_builder()
    }
  end

  def move_to_destination(%{bucket: bucket, query: query}, dest_object, params_or_struct, opts) do
    Core.move_to_destination(
      bucket,
      dest_object,
      query,
      params_or_struct,
      opts
    )
  end

  def move_to_destination(adapter, dest_object, params_or_struct, opts) do
    adapter
    |> __uploader__()
    |> move_to_destination(dest_object, params_or_struct, opts)
  end

  def find_parts(%{bucket: bucket, query: query}, params_or_struct, opts) do
    Core.find_parts(bucket, query, params_or_struct, opts)
  end

  def find_parts(adapter, params_or_struct, opts) do
    adapter
    |> __uploader__()
    |> find_parts(params_or_struct, opts)
  end

  def sign_part(%{bucket: bucket, query: query}, params_or_struct, part_number, opts) do
    Core.sign_part(bucket, query, params_or_struct, part_number, opts)
  end

  def sign_part(adapter, params_or_struct, part_number, opts) do
    adapter
    |> __uploader__()
    |> sign_part(params_or_struct, part_number, opts)
  end

  def complete_multipart_upload(
        %{bucket: bucket, query: query},
        params_or_struct,
        update_params,
        parts,
        builder_schema,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.complete_multipart_upload(
               bucket,
               query,
               params_or_struct,
               update_params,
               parts,
               builder_schema,
               opts
             ),
           {:ok, job} <-
             Engine.enqueue_move_to_destination(
               bucket,
               query,
               payload.data.id,
               payload.destination_object,
               opts
             ) do
        {:ok,
         Map.merge(payload, %{
           jobs: %{
             move_to_destination: job
           }
         })}
      end
    end

    maybe_transaction(fun, opts)
  end

  def complete_multipart_upload(
        adapter,
        params_or_struct,
        update_params,
        parts,
        builder_schema,
        opts
      ) do
    adapter
    |> __uploader__()
    |> complete_multipart_upload(
      params_or_struct,
      update_params,
      parts,
      builder_schema,
      opts
    )
  end

  def abort_multipart_upload(
        %{bucket: bucket, query: query},
        params_or_struct,
        update_params,
        opts
      ) do
    Core.abort_multipart_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      opts
    )
  end

  def abort_multipart_upload(adapter, params_or_struct, update_params, opts) do
    adapter
    |> __uploader__()
    |> abort_multipart_upload(params_or_struct, update_params, opts)
  end

  def create_multipart_upload(
        %{bucket: bucket, query: query},
        filename,
        create_params,
        builder_schema,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.create_multipart_upload(
               bucket,
               query,
               filename,
               create_params,
               builder_schema,
               opts
             ),
           {:ok, job} <-
             Engine.enqueue_abort_expired_multipart_upload(
               bucket,
               query,
               payload.data.id,
               opts
             ) do
        {:ok,
         Map.merge(payload, %{
           jobs: %{
             abort_expired_multipart_upload: job
           }
         })}
      end
    end

    maybe_transaction(fun, opts)
  end

  def create_multipart_upload(adapter, filename, params, opts) do
    adapter
    |> __uploader__()
    |> create_multipart_upload(filename, params, opts)
  end

  def complete_upload(
        %{bucket: bucket, query: query},
        params_or_struct,
        update_params,
        builder_schema,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.complete_upload(
               bucket,
               query,
               params_or_struct,
               update_params,
               builder_schema,
               opts
             ),
           {:ok, job} <-
             Engine.enqueue_move_to_destination(
               bucket,
               query,
               payload.data.id,
               payload.destination_object,
               opts
             ) do
        {:ok,
         Map.merge(payload, %{
           jobs: %{
             move_to_destination: job
           }
         })}
      end
    end

    maybe_transaction(fun, opts)
  end

  def complete_upload(adapter, params_or_struct, update_params, builder_schema, opts) do
    complete_upload(adapter.config(), params_or_struct, update_params, builder_schema, opts)
  end

  def abort_upload(%{bucket: bucket, query: query}, params_or_struct, update_params, opts) do
    Core.abort_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      opts
    )
  end

  def abort_upload(adapter, filename, params, opts) do
    adapter
    |> __uploader__()
    |> abort_upload(filename, params, opts)
  end

  def create_upload(
        %{bucket: bucket, query: query},
        filename,
        create_params,
        builder_schema,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.create_upload(
               bucket,
               query,
               filename,
               create_params,
               builder_schema,
               opts
             ),
           {:ok, job} <-
             Engine.enqueue_abort_expired_upload(
               bucket,
               query,
               payload.data.id,
               opts
             ) do
        {:ok,
         Map.merge(payload, %{
           jobs: %{
             abort_expired_upload: job
           }
         })}
      end
    end

    maybe_transaction(fun, opts)
  end

  def create_upload(adapter, filename, params, opts) do
    adapter
    |> __uploader__()
    |> create_upload(filename, params, opts)
  end

  defp maybe_transaction(fun, opts) do
    if Keyword.get(opts, :transaction_enabled, true) do
      DBAction.transaction(fun, opts)
    else
      fun.()
    end
  end

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      alias Uppy.Uploader

      @bucket opts[:bucket]

      @query opts[:query]

      @path_builder opts[:path_builder]

      def bucket, do: @bucket

      def query, do: @query

      def path_builder, do: @path_builder

      def move_to_destination(dest_object, params_or_struct, opts \\ []) do
        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          opts
        )
      end

      def find_parts(params_or_struct, opts \\ []) do
        Uploader.find_parts(
          __MODULE__,
          params_or_struct,
          opts
        )
      end

      def sign_part(params_or_struct, part_number, opts \\ []) do
        Uploader.sign_part(
          __MODULE__,
          params_or_struct,
          part_number,
          opts
        )
      end

      def complete_multipart_upload(
            params_or_struct,
            update_params,
            parts,
            builder_schema,
            opts \\ []
          ) do
        Uploader.complete_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          parts,
          Keyword.merge(@path_builder, builder_schema),
          opts
        )
      end

      def abort_multipart_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(filename, params, builder_schema, opts \\ []) do
        Uploader.create_multipart_upload(
          __MODULE__,
          filename,
          params,
          Keyword.merge(@path_builder, builder_schema),
          opts
        )
      end

      def complete_upload(params_or_struct, update_params, builder_schema, opts \\ []) do
        Uploader.complete_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          Keyword.merge(@path_builder, builder_schema),
          opts
        )
      end

      def abort_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(filename, params, builder_schema, opts \\ []) do
        Uploader.create_upload(
          __MODULE__,
          filename,
          params,
          Keyword.merge(@path_builder, builder_schema),
          opts
        )
      end

      defoverridable abort_upload: 3,
                     create_upload: 4,
                     complete_upload: 4,
                     abort_multipart_upload: 3,
                     create_multipart_upload: 4,
                     complete_multipart_upload: 4,
                     sign_part: 3,
                     find_parts: 2,
                     move_to_destination: 3
    end
  end
end
