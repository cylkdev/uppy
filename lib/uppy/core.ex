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

  @doc """
  TODO...
  """
  def move_to_destination(bucket, query, %_{} = schema_data, dest_object, opts) do
    resolution =
      Uppy.Resolution.new!(%{
        bucket: bucket,
        query: query,
        value: schema_data,
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
              schema_data: schema_data
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
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      move_to_destination(bucket, query, schema_data, dest_object, opts)
    end
  end

  @doc """
  TODO...
  """
  def find_parts(bucket, _query, %_{} = schema_data, opts) do
    with {:ok, parts} <-
           Storage.list_parts(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ) do
      {:ok,
       %{
         parts: parts,
         schema_data: schema_data
       }}
    end
  end

  def find_parts(bucket, query, find_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_data, opts)
    end
  end

  @doc """
  TODO...
  """
  def sign_part(bucket, _query, %_{} = schema_data, part_number, opts) do
    with {:ok, signed_part} <-
           Storage.sign_part(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
         signed_part: signed_part,
         schema_data: schema_data
       }}
    end
  end

  def sign_part(bucket, query, find_params, part_number, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      sign_part(bucket, query, schema_data, part_number, opts)
    end
  end

  @doc """
  TODO...
  """
  def complete_multipart_upload(
        bucket,
        builder_args,
        query,
        %_{} = schema_data,
        update_params,
        parts,
        opts
      ) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        schema_data,
        unique_identifier,
        builder_args,
        opts
      )

    with {:ok, metadata} <-
           Storage.complete_multipart_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             parts,
             opts
           ) do
      fun = fn ->
        with {:ok, schema_data} <-
               DBAction.update(
                 query,
                 schema_data,
                 Map.merge(update_params, %{
                   state: @completed,
                   unique_identifier: unique_identifier,
                   e_tag: metadata.e_tag
                 }),
                 opts
               ) do
          if Keyword.get(opts, :scheduler_enabled, @scheduler_enabled) do
            with {:ok, job} <-
                   Scheduler.enqueue_move_to_destination(
                     bucket,
                     query,
                     schema_data.id,
                     dest_object,
                     opts
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 schema_data: schema_data,
                 basename: basename,
                 destination_object: dest_object,
                 jobs: %{move_to_destination: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               schema_data: schema_data,
               basename: basename,
               destination_object: dest_object
             }}
          end
        end
      end

      DBAction.transaction(fun, opts)
    end
  end

  def complete_multipart_upload(
        bucket,
        builder_args,
        query,
        find_params,
        update_params,
        parts,
        opts
      ) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        builder_args,
        query,
        schema_data,
        update_params,
        parts,
        opts
      )
    end
  end

  @doc """
  TODO...
  """
  def abort_multipart_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    update_params = Map.put_new(update_params, :state, @aborted)

    with {:ok, metadata} <-
           Storage.abort_multipart_upload(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             opts
           ),
         {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{!=: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def create_multipart_upload(
        bucket,
        builder_args,
        query,
        create_params,
        opts
      ) do
    {basename, key} =
      PathBuilder.build_object_path(
        create_params.filename,
        builder_args,
        opts
      )

    with {:ok, multipart_upload} <- Storage.create_multipart_upload(bucket, key, opts) do
      fun = fn ->
        with {:ok, schema_data} <-
               DBAction.create(
                 query,
                 Map.merge(create_params, %{
                   state: @pending,
                   filename: create_params.filename,
                   key: key,
                   upload_id: multipart_upload.upload_id
                 }),
                 opts
               ) do
          if Keyword.get(opts, :scheduler_enabled, @scheduler_enabled) do
            with {:ok, job} <-
                   Scheduler.enqueue_abort_expired_multipart_upload(
                     bucket,
                     query,
                     schema_data.id,
                     opts
                   ) do
              {:ok,
               %{
                 basename: basename,
                 schema_data: schema_data,
                 multipart_upload: multipart_upload,
                 jobs: %{abort_expired_multipart_upload: job}
               }}
            end
          else
            {:ok,
             %{
               basename: basename,
               schema_data: schema_data,
               multipart_upload: multipart_upload
             }}
          end
        end
      end

      DBAction.transaction(fun, opts)
    end
  end

  @doc """
  TODO...
  """
  def complete_upload(bucket, builder_args, query, %_{} = schema_data, update_params, opts) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        schema_data,
        unique_identifier,
        builder_args,
        opts
      )

    with {:ok, metadata} <- Storage.head_object(bucket, schema_data.key, opts) do
      fun = fn ->
        with {:ok, schema_data} <-
               DBAction.update(
                 query,
                 schema_data,
                 Map.merge(update_params, %{
                   state: @completed,
                   unique_identifier: unique_identifier,
                   e_tag: metadata.e_tag
                 }),
                 opts
               ) do
          if Keyword.get(opts, :scheduler_enabled, @scheduler_enabled) do
            with {:ok, job} <-
                   Scheduler.enqueue_move_to_destination(
                     bucket,
                     query,
                     schema_data.id,
                     dest_object,
                     opts
                   ) do
              {:ok,
               %{
                 metadata: metadata,
                 schema_data: schema_data,
                 basename: basename,
                 destination_object: dest_object,
                 jobs: %{move_to_destination: job}
               }}
            end
          else
            {:ok,
             %{
               metadata: metadata,
               schema_data: schema_data,
               basename: basename,
               destination_object: dest_object
             }}
          end
        end
      end

      DBAction.transaction(fun, opts)
    end
  end

  def complete_upload(bucket, builder_args, query, find_params, update_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{==: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_upload(bucket, builder_args, query, schema_data, update_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def abort_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    update_params = Map.put_new(update_params, :state, @aborted)

    case Storage.head_object(bucket, schema_data.key, opts) do
      {:ok, metadata} ->
        {:error,
         ErrorMessage.forbidden("object exists", %{
           bucket: bucket,
           key: schema_data.key,
           metadata: metadata
         })}

      {:error, %{code: :not_found}} ->
        with {:ok, schema_data} <- DBAction.update(query, schema_data, update_params, opts) do
          {:ok, %{schema_data: schema_data}}
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

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  @doc """
  TODO...
  """
  def create_upload(bucket, builder_args, query, create_params, opts) when is_binary(bucket) do
    {basename, key} = PathBuilder.build_object_path(create_params.filename, builder_args, opts)

    with {:ok, signed_url} <- Storage.pre_sign(bucket, http_method(opts), key, opts) do
      fun = fn ->
        with {:ok, schema_data} <-
               DBAction.create(
                 query,
                 Map.merge(create_params, %{
                   state: @pending,
                   filename: create_params.filename,
                   key: key
                 }),
                 opts
               ) do
          if Keyword.get(opts, :scheduler_enabled, @scheduler_enabled) do
            with {:ok, job} <-
                   Scheduler.enqueue_abort_expired_upload(
                     bucket,
                     query,
                     schema_data.id,
                     opts
                   ) do
              {:ok,
               %{
                 basename: basename,
                 schema_data: schema_data,
                 signed_url: signed_url,
                 jobs: %{abort_expired_upload: job}
               }}
            end
          else
            {:ok,
             %{
               basename: basename,
               schema_data: schema_data,
               signed_url: signed_url
             }}
          end
        end
      end

      DBAction.transaction(fun, opts)
    end
  end

  defp http_method(opts) do
    with val when val not in [:put, :post] <- Keyword.get(opts, :http_method, :put) do
      raise "Expected the option `:http_method` to be :put or :post, got: #{inspect(val)}"
    end
  end
end
