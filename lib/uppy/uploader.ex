defmodule Uppy.Uploader do
  @moduledoc false

  alias Uppy.{
    Core,
    DBAction,
    Uploader.Scheduler
  }

  def new!(opts) do
    struct!(__MODULE__, opts)
  end

  def __uploader__(uploader), do: uploader.__uploader__()

  def bucket(uploader), do: uploader.bucket()

  def query(uploader), do: uploader.query()

  def builder_params(uploader), do: uploader.builder_params()

  def options(uploader), do: uploader.options()

  def move_to_destination(bucket, query, dest_object, params_or_struct, opts) do
    Core.move_to_destination(bucket, dest_object, query, params_or_struct, opts)
  end

  def move_to_destination(uploader, dest_object, params_or_struct, opts) do
    move_to_destination(uploader.bucket(), uploader.query(), dest_object, params_or_struct, opts)
  end

  def find_parts(bucket, query, params_or_struct, opts) do
    Core.find_parts(bucket, query, params_or_struct, opts)
  end

  def find_parts(uploader, params_or_struct, opts) do
    find_parts(uploader.bucket(), uploader.query(), params_or_struct, opts)
  end

  def sign_part(bucket, query, params_or_struct, part_number, opts) do
    Core.sign_part(bucket, query, params_or_struct, part_number, opts)
  end

  def sign_part(uploader, params_or_struct, part_number, opts) do
    sign_part(uploader.bucket(), uploader.query(), params_or_struct, part_number, opts)
  end

  def complete_multipart_upload(
        bucket,
        query,
        params_or_struct,
        update_params,
        parts,
        builder_params,
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
               builder_params,
               opts
             ),
           {:ok, job} <-
             Scheduler.enqueue_move_to_destination(
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
        uploader,
        params_or_struct,
        update_params,
        parts,
        builder_params,
        opts
      ) do
    complete_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      parts,
      builder_params,
      opts
    )
  end

  def abort_multipart_upload(bucket, query, params_or_struct, update_params, opts) do
    Core.abort_multipart_upload(bucket, query, params_or_struct, update_params, opts)
  end

  def abort_multipart_upload(uploader, params_or_struct, update_params, opts) do
    abort_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def create_multipart_upload(
        bucket,
        query,
        filename,
        create_params,
        builder_params,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.create_multipart_upload(
               bucket,
               query,
               filename,
               create_params,
               builder_params,
               opts
             ),
           {:ok, job} <-
             Scheduler.enqueue_abort_expired_multipart_upload(
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

  def create_multipart_upload(uploader, filename, create_params, builder_params, opts) do
    create_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      filename,
      create_params,
      builder_params,
      opts
    )
  end

  def complete_upload(
        bucket,
        query,
        params_or_struct,
        update_params,
        builder_params,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.complete_upload(
               bucket,
               query,
               params_or_struct,
               update_params,
               builder_params,
               opts
             ),
           {:ok, job} <-
             Scheduler.enqueue_move_to_destination(
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

  def complete_upload(uploader, params_or_struct, update_params, builder_params, opts) do
    complete_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      builder_params,
      opts
    )
  end

  def abort_upload(bucket, query, params_or_struct, update_params, opts) do
    Core.abort_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      opts
    )
  end

  def abort_upload(uploader, filename, params, opts) do
    abort_upload(uploader.bucket(), uploader.query(), filename, params, opts)
  end

  def create_upload(
        bucket,
        query,
        filename,
        create_params,
        builder_params,
        opts
      ) do
    fun = fn ->
      with {:ok, payload} <-
             Core.create_upload(
               bucket,
               query,
               filename,
               create_params,
               builder_params,
               opts
             ),
           {:ok, job} <-
             Scheduler.enqueue_abort_expired_upload(
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

  def create_upload(uploader, filename, create_params, builder_params, opts) do
    create_upload(
      uploader.bucket(),
      uploader.query(),
      filename,
      create_params,
      builder_params,
      opts
    )
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

      @bucket :bucket

      @query :query

      @builder_params :builder_params

      @options opts[:options]

      def __uploader__ do
        [
          bucket: @bucket,
          query: @query,
          builder_params: @builder_params
        ]
      end

      def bucket, do: @bucket

      def query, do: @query

      def builder_params, do: @builder_params

      def options, do: @options

      def move_to_destination(dest_object, params_or_struct, opts \\ []) do
        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          Keyword.merge(@options, opts)
        )
      end

      def find_parts(params_or_struct, opts \\ []) do
        Uploader.find_parts(
          __MODULE__,
          params_or_struct,
          Keyword.merge(@options, opts)
        )
      end

      def sign_part(params_or_struct, part_number, opts \\ []) do
        Uploader.sign_part(
          __MODULE__,
          params_or_struct,
          part_number,
          Keyword.merge(@options, opts)
        )
      end

      def complete_multipart_upload(
            params_or_struct,
            update_params,
            parts,
            builder_params,
            opts \\ []
          ) do
        Uploader.complete_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          parts,
          Keyword.merge(@builder_params, builder_params),
          Keyword.merge(@options, opts)
        )
      end

      def abort_multipart_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          Keyword.merge(@options, opts)
        )
      end

      def create_multipart_upload(filename, create_params, builder_params, opts \\ []) do
        Uploader.create_multipart_upload(
          __MODULE__,
          filename,
          create_params,
          Keyword.merge(@builder_params, builder_params),
          Keyword.merge(@options, opts)
        )
      end

      def complete_upload(params_or_struct, update_params, builder_params, opts \\ []) do
        Uploader.complete_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          Keyword.merge(@builder_params, builder_params),
          Keyword.merge(@options, opts)
        )
      end

      def abort_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          Keyword.merge(@options, opts)
        )
      end

      def create_upload(filename, create_params, builder_params, opts \\ []) do
        Uploader.create_upload(
          __MODULE__,
          filename,
          create_params,
          Keyword.merge(@builder_params, builder_params),
          Keyword.merge(@options, opts)
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
