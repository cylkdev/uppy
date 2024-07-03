defmodule Uppy.Core do
  @moduledoc false

  alias Uppy.{
    Config,
    Core,
    Core.Definition,
    Actions,
    Error,
    ObjectKey,
    Pipeline,
    Storage,
    Utils
  }

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @type date_time :: DateTime.t()

  @type schema :: module()
  @type schema_data :: struct()
  @type params :: map()
  @type options :: Keyword.t()

  @type unique_identifier :: String.t()
  @type basename :: String.t()
  @type filename :: String.t()
  @type key :: String.t()
  @type url :: String.t()

  @type presigned_upload :: %{
          optional(atom()) => key(),
          url: url(),
          expires_at: date_time()
        }

  @type start_upload_payload :: %{
          unique_identifier: unique_identifier(),
          filename: filename(),
          basename: basename(),
          key: key(),
          presigned_upload: presigned_upload(),
          schema_data: schema_data()
        }

  @enforce_keys [
    :bucket,
    :resource_name,
    :scheduler_adapter,
    :storage_adapter,
    :permanent_object_key_adapter,
    :temporary_object_key_adapter,
    :queryable_owner_association_source,
    :queryable_primary_key_source,
    :parent_association_source,
    :parent_schema,
    :owner_primary_key_source,
    :owner_schema,
    :owner_partition_source
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
          bucket: String.t() | nil,
          resource_name: String.t() | nil,
          scheduler_adapter: module() | nil,
          storage_adapter: module() | nil,
          permanent_object_key_adapter: module() | nil,
          temporary_object_key_adapter: module() | nil,
          parent_association_source: atom() | nil,
          queryable_owner_association_source: atom() | nil,
          queryable_primary_key_source: atom() | nil,
          owner_primary_key_source: atom() | nil,
          owner_schema: module() | nil,
          owner_partition_source: atom() | nil
        }

  @default_attrs [
    scheduler_adapter: Uppy.Adapters.Scheduler.Oban,
    storage_adapter: Uppy.Adapters.Storage.S3,
    permanent_object_key_adapter: Uppy.Adapters.ObjectKey.PermanentObject,
    temporary_object_key_adapter: Uppy.Adapters.ObjectKey.TemporaryObject,
    queryable_primary_key_source: :id,
    queryable_owner_association_source: :user_id,
    parent_association_source: :assoc_id,
    owner_primary_key_source: :id,
    owner_partition_source: :id
  ]

  @default_owner_partition "shared"
  @default_hash_length 20

  @doc false
  @spec validate(attrs :: map() | Keyword.t()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(attrs) when is_map(attrs) do
    attrs |> Map.to_list() |> validate()
  end

  def validate(attrs) do
    with {:ok, attrs} <-
      @default_attrs
      |> Keyword.merge(attrs)
      |> Definition.validate() do
      {:ok, struct!(Core, attrs)}
    end
  end

  @doc false
  @spec validate!(attrs :: map() | Keyword.t()) :: t()
  def validate!(attrs) when is_map(attrs) do
    attrs |> Map.to_list() |> validate!()
  end

  def validate!(attrs) do
    attrs =
      @default_attrs
      |> Keyword.merge(attrs)
      |> Definition.validate!()

    struct!(Core, attrs)
  end

  def presigned_part(
        %Core{
          storage_adapter: storage_adapter,
          bucket: bucket
        } = core,
        schema,
        params,
        part_number,
        options \\ []
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, presigned_part} <-
           Storage.presigned_part_upload(
             storage_adapter,
             bucket,
             fetch_non_nil!(schema_data, :key),
             fetch_non_nil!(schema_data, :upload_id),
             part_number,
             options
           ) do
      {:ok,
       %{
         presigned_part: presigned_part,
         schema_data: schema_data
       }}
    end
  end

  def find_parts(
        %Core{
          storage_adapter: storage_adapter,
          bucket: bucket
        } = core,
        schema,
        params,
        next_part_number_marker \\ nil,
        options \\ []
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, parts} <-
           Storage.list_parts(
             storage_adapter,
             bucket,
             fetch_non_nil!(schema_data, :key),
             fetch_non_nil!(schema_data, :upload_id),
             next_part_number_marker,
             options
           ) do
      {:ok,
       %{
         parts: parts,
         schema_data: schema_data
       }}
    end
  end

  def complete_multipart_upload(
        %Core{
          storage_adapter: storage_adapter,
          bucket: bucket
        } = core,
        schema,
        params,
        parts,
        options
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, metadata} <-
           Storage.complete_multipart_upload(
             storage_adapter,
             bucket,
             fetch_non_nil!(schema_data, :key),
             fetch_non_nil!(schema_data, :upload_id),
             parts,
             options
           ),
         e_tag <- fetch_non_nil!(metadata, :e_tag),
         {:ok, schema_data} <-
           actions_update(schema, schema_data, %{e_tag: e_tag}, options) do
      {:ok,
       %{
         multipart: true,
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def abort_multipart_upload(
        %Core{
          storage_adapter: storage_adapter,
          bucket: bucket
        } = core,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, maybe_abort_multipart_upload_payload} <-
           maybe_abort_multipart_upload(
             storage_adapter,
             bucket,
             fetch_non_nil!(schema_data, :key),
             fetch_non_nil!(schema_data, :upload_id),
             options
           ),
         {:ok, schema_data} <- actions_delete(schema_data, options) do
      {:ok,
       Map.merge(maybe_abort_multipart_upload_payload, %{
         schema_data: schema_data
       })}
    end
  end

  defp maybe_abort_multipart_upload(
         storage_adapter,
         bucket,
         key,
         upload_id,
         options
       ) do
    case Storage.abort_multipart_upload(storage_adapter, bucket, key, upload_id, options) do
      {:ok, metadata} -> {:ok, %{metadata: metadata}}
      {:error, %{code: :not_found}} -> {:ok, %{}}
      error -> error
    end
  end

  def start_multipart_upload(
        %Core{
          bucket: bucket,
          storage_adapter: storage_adapter,
          temporary_object_key_adapter: temporary_object_key_adapter,
          parent_association_source: parent_association_source,
          queryable_owner_association_source: queryable_owner_association_source
        },
        schema,
        upload_params,
        create_params \\ %{},
        options \\ []
      ) do
    assoc_id = upload_params[:assoc_id]
    owner_id = upload_params.owner_id

    object_config =
      temporary_object_config(
        temporary_object_key_adapter,
        owner_id,
        Map.fetch!(create_params, :filename),
        options
      )

    params =
      create_params
      |> Map.merge(%{
        key: object_config.key,
        unique_identifier: object_config.unique_identifier,
        filename: object_config.filename
      })
      |> Map.put(queryable_owner_association_source, owner_id)
      |> Map.put(parent_association_source, assoc_id)

    with {:ok, multipart_upload} <-
           Storage.initiate_multipart_upload(
             storage_adapter,
             bucket,
             object_config.key,
             options
           ),
         params <- Map.put(params, :upload_id, multipart_upload),
         {:ok, schema_data} <- actions_create(schema, params, options) do
      {:ok,
       Map.merge(object_config, %{
         multipart_upload: multipart_upload,
         schema_data: schema_data
       })}
    end
  end

  def move_upload_to_permanent_storage(
        %Core{} = core,
        schema,
        params,
        pipeline,
        options \\ []
      ) do
    with {:ok, schema_data} <-
           find_completed_pending_upload(core, schema, params, options),
         {:ok, owner} <-
           find_schema_data_owner(core, schema_data, options),
         object_config <-
           permanent_object_config(core, schema_data, owner),
         {:ok, pipeline_payload} <-
           run_pipeline(
             pipeline,
             object_config.destination_object,
             object_config.source_object,
             schema_data,
             owner,
             options
           ) do
      {:ok,
       Map.merge(object_config, %{
         pipeline: pipeline_payload,
         schema_data: schema_data,
         owner: owner
       })}
    end
  end

  defp permanent_object_config(
         %Core{
           resource_name: resource_name,
           permanent_object_key_adapter: permanent_object_key_adapter,
           owner_partition_source: owner_partition_source
         },
         schema_data,
         owner
       ) do
    unique_identifier = fetch_non_nil!(schema_data, :unique_identifier)
    filename = fetch_non_nil!(schema_data, :filename)
    basename = basename(unique_identifier, filename)

    source_object = fetch_non_nil!(schema_data, :key)

    destination_object =
      ObjectKey.build(
        permanent_object_key_adapter,
        resource_name: resource_name,
        basename: basename,
        id: owner_partition(owner, owner_partition_source)
      )

    %{
      source_object: source_object,
      destination_object: destination_object
    }
  end

  defp run_pipeline(
         pipeline,
         dest_object,
         src_object,
         schema_data,
         owner,
         options
       ) do
    input = %{
      schema_data: schema_data,
      owner: owner,
      destination_object: dest_object,
      source_object: src_object,
      private: %{},
      options: options
    }

    with {:ok, output, done} <- Pipeline.run(input, pipeline) do
      {:ok, %{output: output, phases: done}}
    end
  end

  def complete_upload(
        %Core{
          bucket: bucket,
          storage_adapter: storage_adapter
        } = core,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_non_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         key <- fetch_non_nil!(schema_data, :key),
         {:ok, metadata} <-
           Storage.head_object(storage_adapter, bucket, key, options),
         e_tag <- fetch_non_nil!(metadata, :e_tag),
         {:ok, schema_data} <-
           actions_update(schema, schema_data, %{e_tag: e_tag}, options) do
      {:ok,
       %{
         metadata: metadata,
         schema_data: schema_data
       }}
    end
  end

  def delete_aborted_upload_object(
        %Core{
          bucket: bucket,
          storage_adapter: storage_adapter
        },
        schema,
        key,
        options \\ []
      ) do
    with :ok <- ensure_not_found(schema, %{key: key}, options),
         {:ok, metadata} <- Storage.head_object(storage_adapter, bucket, key, options),
         {:ok, _} <- Storage.delete_object(storage_adapter, bucket, key, options) do
      {:ok, metadata}
    end
  end

  @doc """
  ...
  """
  def abort_upload(%Core{} = core, schema, params, options \\ []) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options),
         {:ok, schema_data} <-
           check_if_non_multipart_upload(
             schema_data,
             %{
               schema: schema,
               schema_data: schema_data,
               params: params
             },
             options
           ),
         {:ok, schema_data} <- actions_delete(schema_data, options) do
      {:ok, %{schema_data: schema_data}}
    end
  end

  def find_completed_pending_upload(
        %Core{} = core,
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_pending_upload(core, schema, params, options) do
      if is_binary(schema_data.e_tag) do
        {:ok, schema_data}
      else
        {:error,
         Error.call(
           :forbidden,
           "upload incomplete",
           %{
             schema: schema,
             params: params
           }
         )}
      end
    end
  end

  @doc """
  ...
  """
  def find_pending_upload(
        %Core{
          temporary_object_key_adapter: temporary_object_key_adapter
        },
        schema,
        params,
        options
      ) do
    with {:ok, schema_data} <- actions_find(schema, params, options) do
      check_upload_in_progress(
        temporary_object_key_adapter,
        schema_data,
        %{
          schema: schema,
          schema_data: schema_data,
          params: params
        },
        options
      )
    end
  end

  @doc """
  Creates a presigned upload and database record.

  Note: All none web safe characters will be removed from the `filename`.

  This operation is executed as follows:

      - A presigned upload payload is created. This payload contains the fields `url` and `expires_at`.
        The `url` can be used by a client to make a HTTP request and upload their data to storage.
        The `expires_at` is the timestamp for when the presigned url is expired and can no longer
        be used.

      - Creates a database record with the `create_params` and adds `key`, `unique_identifier`, and
        `filename` to the parameters. The presigned url in the upload uses the returned values for `key`,
        `unique_identifier`, and `filename` which restricts the `destination` to the specified `key`.

  ### Examples

      > Uppy.Core.start_upload(Uppy.Core.create_struct(), %{assoc_id: 1, owner_id: 1}, %{filename: "image.jpeg"})

      > Uppy.Core.start_upload(Uppy.Core.create_struct(), %{owner_id: 1}, %{filename: "image.jpeg"})
  """
  def start_upload(
        %Core{
          bucket: bucket,
          storage_adapter: storage_adapter,
          temporary_object_key_adapter: temporary_object_key_adapter,
          parent_association_source: parent_association_source,
          queryable_owner_association_source: queryable_owner_association_source
        },
        schema,
        upload_params,
        create_params \\ %{},
        options \\ []
      ) do
    assoc_id = upload_params[:assoc_id]
    owner_id = upload_params.owner_id

    object_config =
      temporary_object_config(
        temporary_object_key_adapter,
        owner_id,
        Map.fetch!(create_params, :filename),
        options
      )

    params =
      create_params
      |> Map.merge(%{
        key: object_config.key,
        unique_identifier: object_config.unique_identifier,
        filename: object_config.filename
      })
      |> Map.put(queryable_owner_association_source, owner_id)
      |> Map.put(parent_association_source, assoc_id)

    with {:ok, presigned_upload} <-
           Storage.presigned_upload(storage_adapter, bucket, object_config.key, options),
         {:ok, schema_data} <- actions_create(schema, params, options) do
      {:ok,
       Map.merge(object_config, %{
         presigned_upload: presigned_upload,
         schema_data: schema_data
       })}
    end
  end

  defp temporary_object_config(temporary_object_key_adapter, owner_id, filename, options) do
    unique_identifier = generate_unique_identifier(options)
    filename = Utils.filter_web_safe_code_points(filename)
    basename = basename(unique_identifier, filename)

    key =
      ObjectKey.build(
        temporary_object_key_adapter,
        id: "#{owner_id}",
        basename: basename
      )

    %{
      unique_identifier: unique_identifier,
      filename: filename,
      key: key
    }
  end

  defp find_schema_data_owner(
         %Core{
           owner_schema: owner_schema,
           queryable_owner_association_source: queryable_owner_association_source
         },
         schema_data,
         options
       ) do
    owner_id = Map.fetch!(schema_data, queryable_owner_association_source)

    actions_find(owner_schema, %{queryable_owner_association_source => owner_id}, options)
  end

  defp owner_partition(owner, partition_source) do
    case partition_source do
      nil -> @default_owner_partition
      false -> @default_owner_partition
      key -> "#{fetch_non_nil!(owner, key)}"
    end
  end

  defp generate_unique_identifier(options) do
    hash_length = Keyword.get(options, :hash_length, @default_hash_length)

    Utils.generate_unique_identifier(hash_length)
  end

  defp basename(unique_identifier, path) do
    "#{unique_identifier}-#{path}"
  end

  defp check_upload_in_progress(temporary_object_key_adapter, schema_data, details, options) do
    key = fetch_non_nil!(schema_data, :key)

    if ObjectKey.path?(temporary_object_key_adapter, key: key) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden, "upload not in progress", details, options)}
    end
  end

  defp check_if_multipart_upload(schema_data, details, options) do
    if has_upload_id?(schema_data) do
      {:ok, schema_data}
    else
      {:error, Error.call(:forbidden, "must be a multipart upload", details, options)}
    end
  end

  defp check_if_non_multipart_upload(schema_data, details, options) do
    if has_upload_id?(schema_data) do
      {:error, Error.call(:forbidden, "must be a non multipart upload", details, options)}
    else
      {:ok, schema_data}
    end
  end

  defp has_upload_id?(%{upload_id: nil}), do: false
  defp has_upload_id?(%{upload_id: _upload_id}), do: true

  defp ensure_not_found(schema, params, options) do
    case actions_find(schema, params, options) do
      {:ok, schema_data} ->
        {:error,
         Error.call(:forbidden, "record found", %{
           schema: schema,
           params: params,
           schema_data: schema_data
         })}

      {:error, %{code: :not_found}} ->
        :ok

      error ->
        error
    end
  end

  defp actions_create(schema, params, options) do
    Actions.create(Config.actions_adapter(), schema, params, options)
  end

  defp actions_find(schema, params, options) do
    Actions.find(Config.actions_adapter(), schema, params, options)
  end

  defp actions_update(schema, schema_data, params, options) do
    Actions.update(Config.actions_adapter(), schema, schema_data, params, options)
  end

  defp actions_delete(schema_data, options) do
    Actions.delete(Config.actions_adapter(), schema_data, options)
  end

  # This is used to fetch data from maps that may contain the keys that
  # have nil values (ie. structs) as it provides an early check where
  # the next function could fail due to a nil argument or create an
  # invalid state.
  defp fetch_non_nil!(map, key) do
    case Map.get(map, key) do
      nil -> raise "value for `#{key}` cannot be nil, got:\n\n#{inspect(map, pretty: true)}"
      value -> value
    end
  end
end
