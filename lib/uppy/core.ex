defmodule Uppy.Core do
  @moduledoc """
  """

  alias Uppy.{
    DBAction,
    PathBuilder,
    Pipeline,
    Storage
  }

  @aborted :aborted
  @completed :completed
  @pending :pending

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
        builder_params,
        opts
      ) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        :complete_multipart_upload,
        struct,
        unique_identifier,
        builder_params,
        opts
      )

    with {:ok, metadata} <- Storage.complete_multipart_upload(bucket, struct, parts, opts),
         {:ok, struct} <-
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
      {:ok,
       %{
         metadata: metadata,
         data: struct,
         basename: basename,
         destination_object: dest_object
       }}
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
        builder_params,
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
  def create_multipart_upload(bucket, query, filename, create_params, builder_params, opts) do
    {basename, key} =
      PathBuilder.build_object_path(
        :create_multipart_upload,
        filename,
        builder_params,
        opts
      )

    with {:ok, mpu} <- Storage.create_multipart_upload(bucket, key, opts),
         {:ok, struct} <-
           DBAction.create(
             query,
             Map.merge(create_params, %{
               state: @pending,
               filename: filename,
               key: key,
               upload_id: mpu.upload_id
             }),
             opts
           ) do
      {:ok,
       %{
         basename: basename,
         data: struct,
         multipart_upload: mpu
       }}
    end
  end

  @doc """
  TODO...
  """
  def complete_upload(bucket, query, %_{} = struct, update_params, builder_params, opts) do
    unique_identifier = update_params[:unique_identifier]

    {basename, dest_object} =
      PathBuilder.build_object_path(
        :complete_upload,
        struct,
        unique_identifier,
        builder_params,
        opts
      )

    with {:ok, metadata} <- Storage.head_object(bucket, struct.key, opts),
         {:ok, struct} <-
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
      {:ok,
       %{
         metadata: metadata,
         data: struct,
         basename: basename,
         destination_object: dest_object
       }}
    end
  end

  def complete_upload(bucket, query, find_params, update_params, builder_params, opts) do
    find_params =
      find_params
      |> Map.put_new(:state, @pending)
      |> Map.put_new(:upload_id, %{==: nil})

    with {:ok, struct} <- DBAction.find(query, find_params, opts) do
      complete_upload(bucket, query, struct, update_params, builder_params, opts)
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
  def create_upload(bucket, query, filename, create_params, builder_params, opts) do
    {basename, key} =
      PathBuilder.build_object_path(
        :create_upload,
        filename,
        builder_params,
        opts
      )

    with {:ok, signed_url} <- Storage.pre_sign(bucket, http_method(opts), key, opts),
         {:ok, struct} <-
           DBAction.create(
             query,
             Map.merge(create_params, %{
               state: @pending,
               filename: filename,
               key: key
             }),
             opts
           ) do
      {:ok,
       %{
         basename: basename,
         data: struct,
         signed_url: signed_url
       }}
    end
  end

  defp http_method(opts) do
    with val when val not in [:put, :post] <- Keyword.get(opts, :http_method, :put) do
      raise "Expected the option `:http_method` to be :put or :post, got: #{inspect(val)}"
    end
  end
end

# defmodule Uppy.Core do
#   @moduledoc """
#   """

#   alias Uppy.{
#     Config,
#     DBAction,
#     Pipeline,
#     Scheduler,
#     Storage
#   }

#   @aborted :aborted
#   @completed :completed
#   @pending :pending

#   @uploads "uploads"
#   @user "user"

#   @default_permanent_prefix ""
#   @temp_prefix "temp/"

#   def move_to_destination(bucket, query, %_{} = struct, dest_object, opts) do
#     resolution =
#       Uppy.Resolution.new!(%{
#         bucket: bucket,
#         query: query,
#         value: struct,
#         arguments: %{
#           destination_object: dest_object
#         }
#       })

#     phases =
#       case Config.pipeline_module() do
#         nil ->
#           Uppy.Core.Pipelines.post_processing(opts)

#         pipeline_module ->
#           pipeline_module.move_to_destination(
#             %{
#               bucket: bucket,
#               destination_object: dest_object,
#               query: query,
#               data: struct
#             },
#             opts
#           )
#       end

#     with {:ok, resolution, done} <- Pipeline.run(resolution, phases) do
#       {:ok,
#        %{
#          resolution: %{resolution | state: :resolved},
#          done: done
#        }}
#     end
#   end

#   def move_to_destination(bucket, query, find_params, dest_object, opts) do
#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       move_to_destination(bucket, query, struct, dest_object, opts)
#     end
#   end

#   def find_parts(
#         bucket,
#         _query,
#         %_{} = struct,
#         opts
#       ) do
#     with {:ok, parts} <-
#            Storage.list_parts(
#              bucket,
#              struct.key,
#              struct.upload_id,
#              opts
#            ) do
#       {:ok,
#        %{
#          parts: parts,
#          data: struct
#        }}
#     end
#   end

#   def find_parts(bucket, query, find_params, opts) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{!=: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       find_parts(bucket, query, struct, opts)
#     end
#   end

#   def sign_part(bucket, _query, %_{} = struct, part_number, opts) do
#     with {:ok, signed_part} <-
#            Storage.sign_part(
#              bucket,
#              struct.key,
#              struct.upload_id,
#              part_number,
#              opts
#            ) do
#       {:ok,
#        %{
#          signed_part: signed_part,
#          data: struct
#        }}
#     end
#   end

#   def sign_part(bucket, query, find_params, part_number, opts) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{!=: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       sign_part(bucket, query, struct, part_number, opts)
#     end
#   end

#   def complete_multipart_upload(
#         bucket,
#         object_key,
#         query,
#         %_{} = struct,
#         update_params,
#         parts,
#         opts
#       ) do
#     unique_identifier = update_params[:unique_identifier] || generate_unique_identifier()

#     basename =
#       if unique_identifier in [nil, ""] do
#         struct.filename
#       else
#         "#{unique_identifier}-#{struct.filename}"
#       end

#     dest_object =
#       basename
#       |> build_build_permanent_object_path(struct, object_key, opts)
#       |> URI.encode()

#     update_params =
#       update_params
#       |> Map.put_new(:state, @completed)
#       |> Map.put(:unique_identifier, unique_identifier)

#     with {:ok, metadata} <- complete_storage_mpu(bucket, struct, parts, opts) do
#       if scheduler_enabled?(opts) do
#         op = fn ->
#           with {:ok, struct} <-
#                  DBAction.update(
#                    query,
#                    struct,
#                    Map.put(update_params, :e_tag, metadata.e_tag),
#                    opts
#                  ),
#                {:ok, job} <-
#                  Scheduler.enqueue_move_to_destination(
#                    bucket,
#                    query,
#                    struct.id,
#                    dest_object,
#                    opts
#                  ) do
#             {:ok,
#              %{
#                metadata: metadata,
#                data: struct,
#                destination_object: dest_object,
#                jobs: %{move_to_destination: job}
#              }}
#           end
#         end

#         DBAction.transaction(op, opts)
#       else
#         with {:ok, struct} <-
#                DBAction.update(
#                  query,
#                  struct,
#                  Map.put(update_params, :e_tag, metadata.e_tag),
#                  opts
#                ) do
#           {:ok,
#            %{
#              metadata: metadata,
#              data: struct,
#              destination_object: dest_object
#            }}
#         end
#       end
#     end
#   end

#   def complete_multipart_upload(
#         bucket,
#         object_key,
#         query,
#         find_params,
#         update_params,
#         parts,
#         opts
#       ) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{!=: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       complete_multipart_upload(
#         bucket,
#         object_key,
#         query,
#         struct,
#         update_params,
#         parts,
#         opts
#       )
#     end
#   end

#   defp complete_storage_mpu(bucket, struct, parts, opts) do
#     case Storage.complete_multipart_upload(
#            bucket,
#            struct.key,
#            struct.upload_id,
#            parts,
#            opts
#          ) do
#       {:ok, _} -> Storage.head_object(bucket, struct.key, opts)
#       {:error, %{code: :not_found}} -> Storage.head_object(bucket, struct.key, opts)
#       {:error, _} = error -> error
#     end
#   end

#   def abort_multipart_upload(bucket, query, %_{} = struct, update_params, opts) do
#     update_params = Map.put_new(update_params, :state, @aborted)

#     with {:ok, metadata} <-
#            Storage.abort_multipart_upload(
#              bucket,
#              struct.key,
#              struct.upload_id,
#              opts
#            ),
#          {:ok, struct} <- DBAction.update(query, struct, update_params, opts) do
#       {:ok,
#        %{
#          metadata: metadata,
#          data: struct
#        }}
#     end
#   end

#   def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{!=: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       abort_multipart_upload(bucket, query, struct, update_params, opts)
#     end
#   end

#   def create_multipart_upload(bucket, object_key, query, filename, create_params, opts) do
#     basename_prefix = opts[:path_builder][:basename_prefix] || String.reverse("#{:os.system_time()}")

#     basename =
#       if basename_prefix in [nil, ""] do
#         filename
#       else
#         "#{basename_prefix}-#{filename}"
#       end

#     key =
#       basename
#       |> build_temporary_object_path(object_key, opts)
#       |> URI.encode()

#     create_params =
#       Map.merge(create_params, %{
#         state: @pending,
#         filename: filename,
#         key: key
#       })

#     with {:ok, multipart_upload} <- Storage.create_multipart_upload(bucket, key, opts) do
#       create_params = Map.put(create_params, :upload_id, multipart_upload.upload_id)

#       if scheduler_enabled?(opts) do
#         op = fn ->
#           with {:ok, struct} <- DBAction.create(query, create_params, opts),
#                {:ok, job} <-
#                  Scheduler.enqueue_abort_expired_multipart_upload(
#                    bucket,
#                    query,
#                    struct.id,
#                    opts
#                  ) do
#             {:ok,
#              %{
#                multipart_upload: multipart_upload,
#                data: struct,
#                jobs: %{abort_expired_multipart_upload: job}
#              }}
#           end
#         end

#         DBAction.transaction(op, opts)
#       else
#         with {:ok, struct} <- DBAction.create(query, create_params, opts) do
#           {:ok,
#            %{
#              multipart_upload: multipart_upload,
#              data: struct
#            }}
#         end
#       end
#     end
#   end

#   def complete_upload(bucket, object_key, query, %_{} = struct, update_params, opts) do
#     unique_identifier = update_params[:unique_identifier] || generate_unique_identifier()

#     basename =
#       if unique_identifier in [nil, ""] do
#         struct.filename
#       else
#         "#{unique_identifier}-#{struct.filename}"
#       end

#     dest_object =
#       basename
#       |> build_build_permanent_object_path(struct, object_key, opts)
#       |> URI.encode()

#     update_params =
#       Map.merge(update_params, %{
#         state: @completed,
#         unique_identifier: unique_identifier
#       })

#     with {:ok, metadata} <- Storage.head_object(bucket, struct.key, opts) do
#       if scheduler_enabled?(opts) do
#         op = fn ->
#           with {:ok, struct} <-
#                  DBAction.update(
#                    query,
#                    struct,
#                    Map.put(update_params, :e_tag, metadata.e_tag),
#                    opts
#                  ),
#                {:ok, job} <-
#                  Scheduler.enqueue_move_to_destination(
#                    bucket,
#                    query,
#                    struct.id,
#                    dest_object,
#                    opts
#                  ) do
#             {:ok,
#              %{
#                metadata: metadata,
#                data: struct,
#                destination_object: dest_object,
#                jobs: %{move_to_destination: job}
#              }}
#           end
#         end

#         DBAction.transaction(op, opts)
#       else
#         with {:ok, struct} <-
#                DBAction.update(
#                  query,
#                  struct,
#                  Map.put(update_params, :e_tag, metadata.e_tag),
#                  opts
#                ) do
#           {:ok,
#            %{
#              metadata: metadata,
#              data: struct,
#              destination_object: dest_object
#            }}
#         end
#       end
#     end
#   end

#   def complete_upload(bucket, object_key, query, find_params, update_params, opts) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{==: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       complete_upload(bucket, object_key, query, struct, update_params, opts)
#     end
#   end

#   def abort_upload(bucket, query, %_{} = struct, update_params, opts) do
#     update_params = Map.put_new(update_params, :state, @aborted)

#     case Storage.head_object(bucket, struct.key, opts) do
#       {:ok, metadata} ->
#         {:error,
#          ErrorMessage.forbidden("object exists", %{
#            bucket: bucket,
#            key: struct.key,
#            metadata: metadata
#          })}

#       {:error, %{code: :not_found}} ->
#         with {:ok, struct} <- DBAction.update(query, struct, update_params, opts) do
#           {:ok, %{data: struct}}
#         end

#       e ->
#         e
#     end
#   end

#   def abort_upload(bucket, query, find_params, update_params, opts) do
#     find_params =
#       find_params
#       |> Map.put_new(:state, @pending)
#       |> Map.put_new(:upload_id, %{==: nil})

#     with {:ok, struct} <- DBAction.find(query, find_params, opts) do
#       abort_upload(bucket, query, struct, update_params, opts)
#     end
#   end

#   @doc """
#   Creates a pre-signed url for `filename`, a record, and
#   schedules a job to abort the upload if not completed in
#   the given time.

#   This function resolves as follows:

#     - Generates a temporary object key to determine the
#       location of the file.

#     - Generates a pre-signed url which allows the client
#       to upload a file to the pre-defined location.

#     - Creates a record with the temporary object key.

#   ### Examples

#       iex> Uppy.Core.create_upload("bucket", %{}, {"user_avatar_file_infos", FileInfoAbstract}, "image.jpeg", %{}, basename_prefix: "timestamp")
#   """
#   def create_upload(bucket, object_key, query, filename, create_params, opts \\ []) do
#     basename_prefix = opts[:path_builder][:basename_prefix] || String.reverse("#{:os.system_time()}")

#     basename =
#       if basename_prefix in [nil, ""] do
#         filename
#       else
#         "#{basename_prefix}-#{filename}"
#       end

#     key =
#       basename
#       |> build_temporary_object_path(object_key, opts)
#       |> URI.encode()

#     create_params =
#       Map.merge(create_params, %{
#         state: @pending,
#         filename: filename,
#         key: key
#       })

#     with {:ok, signed_url} <- Storage.pre_sign(bucket, http_method(opts), key, opts) do
#       if scheduler_enabled?(opts) do
#         op = fn ->
#           with {:ok, struct} <- DBAction.create(query, create_params, opts),
#                {:ok, job} <-
#                  Scheduler.enqueue_abort_expired_upload(
#                    bucket,
#                    query,
#                    struct.id,
#                    opts
#                  ) do
#             {:ok,
#              %{
#                signed_url: signed_url,
#                data: struct,
#                jobs: %{abort_expired_upload: job}
#              }}
#           end
#         end

#         DBAction.transaction(op, opts)
#       else
#         with {:ok, struct} <- DBAction.create(query, create_params, opts) do
#           {:ok,
#            %{
#              signed_url: signed_url,
#              data: struct
#            }}
#         end
#       end
#     end
#   end

#   defp scheduler_enabled?(opts) do
#     opts[:scheduler_enabled] || Uppy.Config.scheduler_enabled() || true
#   end

#   defp build_build_permanent_object_path(basename, %module{} = struct, object_key, opts) do
#     case opts[:build_permanent_object_path] do
#       fun when is_function(fun, 2) ->
#         fun.(basename, struct)

#       _ ->
#         prefix = object_key[:permanent_object_prefix] || @default_permanent_prefix

#         partition_id =
#           case object_key[:permanent_object_partition_id] do
#             nil ->
#               nil

#             partition_id ->
#               if object_key[:reverse_partition_id] === true do
#                 partition_id |> to_string() |> String.reverse()
#               else
#                 partition_id
#               end
#           end

#         partition_name = object_key[:permanent_object_partition_name] || @uploads

#         resource_name = module |> Module.split() |> List.last() |> Macro.underscore()

#         Path.join([
#           prefix,
#           Enum.join([partition_id, partition_name], "-"),
#           resource_name,
#           basename
#         ])
#     end
#   end

#   defp build_temporary_object_path(basename, object_key, opts) do
#     case opts[:temporary_object_key] do
#       fun when is_function(fun, 1) ->
#         fun.(basename)

#       _ ->
#         prefix = object_key[:temporary_object_prefix] || @temp_prefix

#         partition_id =
#           case object_key[:temporary_object_partition_id] do
#             nil ->
#               nil

#             partition_id ->
#               if object_key[:reverse_partition_id] === true do
#                 partition_id |> to_string() |> String.reverse()
#               else
#                 partition_id
#               end
#           end

#         partition_name = object_key[:temporary_object_partition_name] || @user

#         Path.join([prefix, Enum.join([partition_id, partition_name], "-"), basename])
#     end
#   end

#   defp http_method(opts) do
#     with val when val not in [:put, :post] <- Keyword.get(opts, :http_method, :put) do
#       raise "Expected the option `:http_method` to be :put or :post, got: #{inspect(val)}"
#     end
#   end

#   defp generate_unique_identifier do
#     4 |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false)
#   end
# end
