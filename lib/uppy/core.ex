defmodule Uppy.Core do
  @moduledoc """
  """

  alias Uppy.{
    Scheduler,
    DBAction,
    PathBuilder,
    Pipeline,
    Storage
  }

  @completed :completed
  @aborted :aborted
  @pending :pending

  @scheduler_enabled true
  @transaction_enabled true

  @doc """
  TODO...
  """
  def move_to_destination(bucket, query, %_{} = struct, dest_object, opts) do
    resolution =
      Uppy.Resolution.new!(%{
        bucket: bucket,
        query: query,
        value: struct,
        arguments: %{
          destination_object: dest_object
        }
      })

    phases =
      case opts[:pipeline] do
        nil ->
          Uppy.Pipelines.pipeline_for(:move_to_destination, opts)

        module ->
          module.pipeline_for(
            :move_to_destination,
            %{
              bucket: bucket,
              destination_object: dest_object,
              query: query,
              data: struct
            },
            opts
          )
      end

    with {:ok, resolution, done} <- Pipeline.run(resolution, phases) do
      {:ok,
       %{
         resolution: %{resolution | state: :resolved},
         done: done
       }}
    end
  end

  def move_to_destination(bucket, query, find_params, dest_object, opts) do
    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      move_to_destination(bucket, query, struct, dest_object, opts)
    end
  end

  @doc """
  TODO...
  """
  def find_parts(
        bucket,
        _query,
        %_{} = struct,
        opts
      ) do
    with {:ok, parts} <-
           Storage.list_parts(
             bucket,
             struct.key,
             struct.upload_id,
             opts
           ) do
      {:ok,
       %{
         parts: parts,
         data: struct
       }}
    end
  end

  def find_parts(bucket, query, find_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, struct, opts)
    end
  end

  @doc """
  TODO...
  """
  def sign_part(bucket, _query, %_{} = struct, part_number, opts) do
    with {:ok, signed_part} <-
           Storage.sign_part(
             bucket,
             struct.key,
             struct.upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
         signed_part: signed_part,
         data: struct
       }}
    end
  end

  def sign_part(bucket, query, find_params, part_number, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      sign_part(bucket, query, struct, part_number, opts)
    end
  end

  @doc """
  TODO...
  """
  def complete_multipart_upload(
        bucket,
        query,
        %_{} = struct,
        update_params,
        parts,
        path_params,
        opts
      ) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        :complete_multipart_upload,
        struct,
        unique_identifier,
        path_params,
        opts
      )

    with {:ok, metadata} <- Storage.complete_multipart_upload(bucket, struct, parts, opts) do
      fun = fn ->
        with {:ok, struct} <-
               DBAction.update(
                 query,
                 struct,
                 Map.merge(update_params, %{
                   state: @completed,
                   unique_identifier: unique_identifier,
                   e_tag: metadata.e_tag
                 }),
                 opts
               ) do
          if scheduler_enabled?(opts) do
            with {:ok, job} <-
                   Scheduler.enqueue_move_to_destination(
                     bucket,
                     query,
                     struct.id,
                     dest_object,
                     opts
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 data: struct,
                 basename: basename,
                 destination_object: dest_object,
                 jobs: %{move_to_destination: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               data: struct,
               basename: basename,
               destination_object: dest_object
             }}
          end
        end
      end

      maybe_transaction(fun, opts)
    end
  end

  def complete_multipart_upload(
        bucket,
        query,
        find_params,
        update_params,
        parts,
        path_params,
        opts
      ) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        query,
        struct,
        update_params,
        parts,
        path_params,
        opts
      )
    end
  end

  @doc """
  TODO...
  """
  def abort_multipart_upload(bucket, query, %_{} = struct, update_params, opts) do
    update_params = Map.put_new(update_params, :state, @aborted)

    with {:ok, metadata} <-
           Storage.abort_multipart_upload(
             bucket,
             struct.key,
             struct.upload_id,
             opts
           ),
         {:ok, struct} <- DBAction.update(query, struct, update_params, opts) do
      {:ok,
       %{
         metadata: metadata,
         data: struct
       }}
    end
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, struct, update_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def create_multipart_upload(
        bucket,
        query,
        filename,
        create_params,
        path_params,
        opts
      ) do
    {basename, key} =
      PathBuilder.build_object_path(
        :create_multipart_upload,
        filename,
        path_params,
        opts
      )

    with {:ok, multipart_upload} <- Storage.create_multipart_upload(bucket, key, opts) do
      fun = fn ->
        with {:ok, struct} <-
               DBAction.create(
                 query,
                 Map.merge(create_params, %{
                   state: @pending,
                   filename: filename,
                   key: key,
                   upload_id: multipart_upload.upload_id
                 }),
                 opts
               ) do
          if scheduler_enabled?(opts) do
            with {:ok, job} <-
                   Scheduler.enqueue_abort_expired_multipart_upload(
                     bucket,
                     query,
                     struct.id,
                     opts
                   ) do
              {:ok,
               %{
                 basename: basename,
                 data: struct,
                 multipart_upload: multipart_upload,
                 jobs: %{abort_expired_multipart_upload: job}
               }}
            end
          else
            {:ok,
             %{
               basename: basename,
               data: struct,
               multipart_upload: multipart_upload
             }}
          end
        end
      end

      maybe_transaction(fun, opts)
    end
  end

  @doc """
  TODO...
  """
  def complete_upload(bucket, query, %_{} = struct, update_params, path_params, opts) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        :complete_upload,
        struct,
        unique_identifier,
        path_params,
        opts
      )

    with {:ok, metadata} <- Storage.head_object(bucket, struct.key, opts) do
      fun = fn ->
        with {:ok, struct} <-
               DBAction.update(
                 query,
                 struct,
                 Map.merge(update_params, %{
                   state: @completed,
                   unique_identifier: unique_identifier,
                   e_tag: metadata.e_tag
                 }),
                 opts
               ) do
          if scheduler_enabled?(opts) do
            with {:ok, job} <-
                   Scheduler.enqueue_move_to_destination(
                     bucket,
                     query,
                     struct.id,
                     dest_object,
                     opts
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 data: struct,
                 basename: basename,
                 destination_object: dest_object,
                 jobs: %{move_to_destination: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               data: struct,
               basename: basename,
               destination_object: dest_object
             }}
          end
        end
      end

      maybe_transaction(fun, opts)
    end
  end

  def complete_upload(bucket, query, find_params, update_params, path_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{==: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      complete_upload(bucket, query, struct, update_params, path_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def abort_upload(bucket, query, %_{} = struct, update_params, opts) do
    update_params = Map.put_new(update_params, :state, @aborted)

    case Storage.head_object(bucket, struct.key, opts) do
      {:ok, metadata} ->
        {:error,
         ErrorMessage.forbidden("object exists", %{
           bucket: bucket,
           key: struct.key,
           metadata: metadata
         })}

      {:error, %{code: :not_found}} ->
        with {:ok, struct} <- DBAction.update(query, struct, update_params, opts) do
          {:ok, %{data: struct}}
        end

      e ->
        e
    end
  end

  def abort_upload(bucket, query, find_params, update_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{==: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, struct, update_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def create_upload(bucket, query, filename, create_params, path_params, opts) do
    {basename, key} =
      PathBuilder.build_object_path(
        :create_upload,
        filename,
        path_params,
        opts
      )

    with {:ok, signed_url} <- Storage.pre_sign(bucket, http_method(opts), key, opts) do
      fun = fn ->
        with {:ok, struct} <-
               DBAction.create(
                 query,
                 Map.merge(create_params, %{
                   state: @pending,
                   filename: filename,
                   key: key
                 }),
                 opts
               ) do
          if scheduler_enabled?(opts) do
            with {:ok, job} <-
                   Scheduler.enqueue_abort_expired_upload(
                     bucket,
                     query,
                     struct.id,
                     opts
                   ) do
              {:ok,
               %{
                 basename: basename,
                 data: struct,
                 signed_url: signed_url,
                 jobs: %{
                   abort_expired_upload: job
                 }
               }}
            end
          else
            {:ok,
             %{
               basename: basename,
               data: struct,
               signed_url: signed_url
             }}
          end
        end
      end

      maybe_transaction(fun, opts)
    end
  end

  defp http_method(opts) do
    with val when val not in [:put, :post] <- Keyword.get(opts, :http_method, :put) do
      raise "Expected the option `:http_method` to be :put or :post, got: #{inspect(val)}"
    end
  end

  defp maybe_transaction(fun, opts) do
    if scheduler_enabled?(opts) and transaction_enabled?(opts) do
      DBAction.transaction(fun, opts)
    else
      fun.()
    end
  end

  defp scheduler_enabled?(opts) do
    opts[:scheduler_enabled] || @scheduler_enabled
  end

  defp transaction_enabled?(opts) do
    opts[:transaction_enabled] || @transaction_enabled
  end
end
