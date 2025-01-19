defmodule Uppy.Core do
  @moduledoc """
  """

  alias Uppy.{
    Config,
    DBAction,
    Pipeline,
    Scheduler,
    Storage
  }

  @aborted :aborted
  @completed :completed
  @pending :pending

  @uploads "uploads"
  @user "user"

  @perm_prefix ""
  @temp_prefix "temp/"

  def move_to_destination(bucket, query, %_{} = schema_data, dest_object, opts) do
    with {:ok, input, done} <-
           %{
             bucket: bucket,
             query: query,
             schema_data: schema_data,
             destination_object: dest_object
           }
           |> Uppy.Core.PipelineInput.new!()
           |> Pipeline.run(get_phases(bucket, query, schema_data, dest_object, opts)) do
      {:ok, %{input: input, done: done}}
    end
  end

  def move_to_destination(bucket, query, find_params, dest_object, opts) do
    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      move_to_destination(bucket, query, schema_data, dest_object, opts)
    end
  end

  defp get_phases(bucket, query, schema_data, dest_object, opts) do
    case Config.pipeline_resolver() do
      nil ->
        [{Uppy.Phases.MoveToDestination, opts}]

      pipeline_resolver ->
        pipeline_resolver.phases(%{
          event: "uppy.move_to_destination",
          bucket: bucket,
          destination_object: dest_object,
          query: query,
          schema_data: schema_data
        })
    end
  end

  def find_parts(
        bucket,
        _query,
        %_{} = schema_data,
        opts
      ) do
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
    find_params = Map.put_new(find_params, :upload_id, %{!=: nil})

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      find_parts(bucket, query, schema_data, opts)
    end
  end

  def sign_part(bucket, _query, %_{} = schema_data, part_number, opts) do
    with {:ok, sign_part} <-
           Storage.sign_part(
             bucket,
             schema_data.key,
             schema_data.upload_id,
             part_number,
             opts
           ) do
      {:ok,
       %{
         sign_part: sign_part,
         schema_data: schema_data
       }}
    end
  end

  def sign_part(bucket, query, find_params, part_number, opts) do
    find_params = Map.merge(%{status: @pending, upload_id: %{!=: nil}}, find_params)

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      sign_part(bucket, query, schema_data, part_number, opts)
    end
  end

  def complete_multipart_upload(
        bucket,
        query,
        %_{} = schema_data,
        update_params,
        parts,
        builder_params,
        opts
      ) do
    unique_identifier = Map.get(update_params, :unique_identifier, generate_unique_identifier())

    basename =
      if unique_identifier in [nil, ""] do
        schema_data.filename
      else
        "#{unique_identifier}-#{schema_data.filename}"
      end

    dest_object =
      basename
      |> build_permanent_object_key(schema_data, builder_params, opts)
      |> URI.encode()

    update_params =
      Map.merge(update_params, %{
        status: @completed,
        unique_identifier: unique_identifier
      })

    with {:ok, metadata} <- do_complete_mpu(bucket, schema_data, parts, opts) do
      if Keyword.get(opts, :enable_scheduler?, false) do
        op = fn ->
          with {:ok, schema_data} <-
                 DBAction.update(
                   query,
                   schema_data,
                   Map.put(update_params, :e_tag, metadata.e_tag),
                   opts
                 ),
               {:ok, job} <-
                 Scheduler.queue_move_to_destination(
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
               destination_object: dest_object,
               jobs: %{move_to_destination: job}
             }}
          end
        end

        DBAction.transaction(op, opts)
      else
        with {:ok, schema_data} <-
               DBAction.update(
                 query,
                 schema_data,
                 Map.put(update_params, :e_tag, metadata.e_tag),
                 opts
               ) do
          {:ok,
           %{
             metadata: metadata,
             schema_data: schema_data,
             destination_object: dest_object
           }}
        end
      end
    end
  end

  def complete_multipart_upload(
        bucket,
        query,
        find_params,
        update_params,
        parts,
        builder_params,
        opts
      ) do
    find_params = Map.merge(%{status: @pending, upload_id: %{!=: nil}}, find_params)

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_multipart_upload(
        bucket,
        query,
        schema_data,
        update_params,
        parts,
        builder_params,
        opts
      )
    end
  end

  defp do_complete_mpu(bucket, schema_data, parts, opts) do
    case Storage.complete_multipart_upload(
           bucket,
           schema_data.key,
           schema_data.upload_id,
           parts,
           opts
         ) do
      {:ok, _} -> Storage.head_object(bucket, schema_data.key, opts)
      {:error, %{code: :not_found}} -> Storage.head_object(bucket, schema_data.key, opts)
      {:error, _} = error -> error
    end
  end

  def abort_multipart_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    update_params = Map.put(update_params, :status, @aborted)

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
    find_params = Map.merge(%{status: @pending, upload_id: %{!=: nil}}, find_params)

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_multipart_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def create_multipart_upload(bucket, query, filename, create_params, builder_params, opts) do
    timestamp = opts[:timestamp] || String.reverse("#{:os.system_time()}")

    basename =
      if timestamp in [nil, ""] do
        filename
      else
        "#{timestamp}-#{filename}"
      end

    key =
      basename
      |> build_temporary_object_key(builder_params, opts)
      |> URI.encode()

    create_params =
      Map.merge(create_params, %{
        status: @pending,
        filename: filename,
        key: key
      })

    with {:ok, multipart_upload} <- Storage.create_multipart_upload(bucket, key, opts) do
      create_params = Map.put(create_params, :upload_id, multipart_upload.upload_id)

      if Keyword.get(opts, :enable_scheduler?, false) do
        op = fn ->
          with {:ok, schema_data} <- DBAction.create(query, create_params, opts),
               {:ok, job} <-
                 Scheduler.queue_abort_expired_multipart_upload(
                   bucket,
                   query,
                   schema_data.id,
                   opts
                 ) do
            {:ok,
             %{
               multipart_upload: multipart_upload,
               schema_data: schema_data,
               jobs: %{abort_upload: job}
             }}
          end
        end

        DBAction.transaction(op, opts)
      else
        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          {:ok,
           %{
             multipart_upload: multipart_upload,
             schema_data: schema_data
           }}
        end
      end
    end
  end

  def complete_upload(bucket, query, %_{} = schema_data, update_params, builder_params, opts) do
    unique_identifier = Map.get(update_params, :unique_identifier, generate_unique_identifier())

    basename =
      if unique_identifier in [nil, ""] do
        schema_data.filename
      else
        "#{unique_identifier}-#{schema_data.filename}"
      end

    dest_object =
      basename
      |> build_permanent_object_key(schema_data, builder_params, opts)
      |> URI.encode()

    update_params =
      Map.merge(update_params, %{
        status: @completed,
        unique_identifier: unique_identifier
      })

    with {:ok, metadata} <- Storage.head_object(bucket, schema_data.key, opts) do
      if Keyword.get(opts, :enable_scheduler?, false) do
        op = fn ->
          with {:ok, schema_data} <-
                 DBAction.update(
                   query,
                   schema_data,
                   Map.put(update_params, :e_tag, metadata.e_tag),
                   opts
                 ),
               {:ok, job} <-
                 Scheduler.queue_move_to_destination(
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
               destination_object: dest_object,
               jobs: %{move_to_destination: job}
             }}
          end
        end

        DBAction.transaction(op, opts)
      else
        with {:ok, schema_data} <-
               DBAction.update(
                 query,
                 schema_data,
                 Map.put(update_params, :e_tag, metadata.e_tag),
                 opts
               ) do
          {:ok,
           %{
             metadata: metadata,
             schema_data: schema_data,
             destination_object: dest_object
           }}
        end
      end
    end
  end

  def complete_upload(bucket, query, find_params, update_params, builder_params, opts) do
    find_params = Map.merge(%{status: @pending, upload_id: %{==: nil}}, find_params)

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      complete_upload(bucket, query, schema_data, update_params, builder_params, opts)
    end
  end

  def abort_upload(bucket, query, %_{} = schema_data, update_params, opts) do
    update_params = Map.put(update_params, :status, @aborted)

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
    find_params = Map.merge(%{status: @pending, upload_id: %{==: nil}}, find_params)

    with {:ok, schema_data} <- DBAction.find(query, find_params, opts) do
      abort_upload(bucket, query, schema_data, update_params, opts)
    end
  end

  def create_upload(bucket, query, filename, create_params, builder_params, opts) do
    timestamp = opts[:timestamp] || String.reverse("#{:os.system_time()}")

    basename =
      if timestamp in [nil, ""] do
        filename
      else
        "#{timestamp}-#{filename}"
      end

    key =
      basename
      |> build_temporary_object_key(builder_params, opts)
      |> URI.encode()

    create_params =
      Map.merge(create_params, %{
        status: @pending,
        filename: filename,
        key: key
      })

    with {:ok, signed_upload} <- Storage.pre_sign(bucket, http_method(opts), key, opts) do
      if Keyword.get(opts, :enable_scheduler?, false) do
        op = fn ->
          with {:ok, schema_data} <- DBAction.create(query, create_params, opts),
               {:ok, job} <-
                 Scheduler.queue_abort_expired_upload(bucket, query, schema_data.id, opts) do
            {:ok,
             %{
               signed_upload: signed_upload,
               schema_data: schema_data,
               jobs: %{abort_upload: job}
             }}
          end
        end

        DBAction.transaction(op, opts)
      else
        with {:ok, schema_data} <- DBAction.create(query, create_params, opts) do
          {:ok,
           %{
             signed_upload: signed_upload,
             schema_data: schema_data
           }}
        end
      end
    end
  end

  defp build_permanent_object_key(basename, %module{} = schema_data, builder_params, opts) do
    case opts[:permanent_object_key] do
      fun when is_function(fun, 3) ->
        fun.(basename, schema_data, opts)

      adapter when is_atom(adapter) and not is_nil(adapter) ->
        adapter.build_permanent_object_key(basename, builder_params, opts)

      _ ->
        prefix = builder_params[:prefix] || @perm_prefix
        partition_id = builder_params[:partition_id]
        partition_name = builder_params[:partition_name] || @uploads

        resource_name = module |> Module.split() |> List.last() |> Macro.underscore()

        Path.join([
          prefix,
          Enum.join([partition_id, partition_name], "-"),
          resource_name,
          basename
        ])
    end
  end

  defp build_temporary_object_key(basename, builder_params, opts) do
    case opts[:temporary_object_key][:resolver] do
      fun when is_function(fun, 2) ->
        fun.(basename, opts)

      adapter when is_atom(adapter) and not is_nil(adapter) ->
        adapter.build_temporary_object_key(adapter, basename, opts)

      _ ->
        prefix = builder_params[:prefix] || @temp_prefix
        partition_id = builder_params[:partition_id]
        partition_name = builder_params[:partition_name] || @user

        Path.join([prefix, Enum.join([partition_id, partition_name], "-"), basename])
    end
  end

  defp http_method(opts) do
    with val when val not in [:put, :post] <- Keyword.get(opts, :http_method, :put) do
      raise "Expected the option `:http_method` to be :put or :post, got: #{inspect(val)}"
    end
  end

  defp generate_unique_identifier do
    4 |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)
  end
end
