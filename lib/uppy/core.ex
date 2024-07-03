defmodule Uppy.Core do
  @moduledoc false

  alias Uppy.{
    Actions,
    Config,
    Core,
    Core.Definition,
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

  defstruct [
    :bucket,
    :resource,
    :scheduler,
    :storage,
    :queryable,
    :queryable_primary_key_source,
    :parent_association_source,
    :parent_schema,
    :owner_schema,
    :owner_association_source,
    :owner_primary_key_source,
    :owner_partition_source,
    :permanent_object_key,
    :temporary_object_key
  ]

  @type t :: %__MODULE__{
          bucket: String.t() | nil,
          resource: String.t() | nil,
          scheduler: module() | nil,
          storage: module() | nil,
          queryable: module() | nil,
          queryable_primary_key_source: atom() | nil,
          parent_schema: module() | nil,
          parent_association_source: atom() | nil,
          owner_schema: module() | nil,
          owner_association_source: atom() | nil,
          owner_primary_key_source: atom() | nil,
          owner_partition_source: atom() | nil,
          permanent_object_key: module() | nil,
          temporary_object_key: module() | nil
        }

  @default_attrs [
    scheduler: Uppy.Adapters.Scheduler.Oban,
    storage: Uppy.Adapters.Storage.S3,
    permanent_object_key: Uppy.Adapters.ObjectKey.PermanentObject,
    temporary_object_key: Uppy.Adapters.ObjectKey.TemporaryObject,
    queryable_primary_key_source: :id,
    owner_association_source: :user_id,
    parent_association_source: :assoc_id,
    owner_primary_key_source: :id,
    owner_partition_source: :id
  ]

  @default_hash_length 20

  @default_owner_partition "shared"

  def create(attrs \\ []), do: struct!(Core, attrs)

  @doc false
  @spec validate(attrs :: map() | Keyword.t()) ::
          {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(attrs) when is_map(attrs) do
    attrs |> Map.to_list() |> validate()
  end

  def validate(attrs) do
    with {:ok, attrs} <-
           @default_attrs
           |> Keyword.merge(attrs)
           |> Definition.validate() do
      {:ok, create(attrs)}
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
          storage: storage,
          bucket: bucket,
          queryable: schema
        } = core,
        params,
        part_number,
        options \\ []
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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
             storage,
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
          storage: storage,
          bucket: bucket,
          queryable: schema
        } = core,
        params,
        next_part_number_marker \\ nil,
        options \\ []
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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
             storage,
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
          storage: storage,
          bucket: bucket,
          queryable: schema
        } = core,
        params,
        parts,
        options
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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
             storage,
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
          storage: storage,
          bucket: bucket,
          queryable: schema
        } = core,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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
         {:ok, maybe_abort_multipart_upload} <-
           maybe_abort_multipart_upload(
             storage,
             bucket,
             fetch_non_nil!(schema_data, :key),
             fetch_non_nil!(schema_data, :upload_id),
             options
           ),
         {:ok, schema_data} <- actions_delete(schema_data, options) do
      {:ok,
       Map.merge(maybe_abort_multipart_upload, %{
         schema_data: schema_data
       })}
    end
  end

  defp maybe_abort_multipart_upload(
         storage,
         bucket,
         key,
         upload_id,
         options
       ) do
    case Storage.abort_multipart_upload(storage, bucket, key, upload_id, options) do
      {:ok, metadata} -> {:ok, %{metadata: metadata}}
      {:error, %{code: :not_found}} -> {:ok, %{}}
      error -> error
    end
  end

  def start_multipart_upload(
        %Core{
          bucket: bucket,
          storage: storage,
          temporary_object_key: temporary_object_key,
          parent_association_source: parent_association_source,
          owner_association_source: owner_association_source,
          queryable: schema
        },
        upload_params,
        params,
        options \\ []
      ) do
    assoc_id = upload_params[:assoc_id]
    owner_id = upload_params.owner_id

    filename = Map.fetch!(params, :filename)

    object_config =
      temporary_object_config(
        temporary_object_key,
        owner_id,
        filename,
        options
      )

    params =
      params
      |> Map.merge(%{
        key: object_config.key,
        unique_identifier: object_config.unique_identifier,
        filename: filename
      })
      |> Map.put(owner_association_source, owner_id)
      |> Map.put(parent_association_source, assoc_id)

    with :ok <- maybe_validate_filename(filename, options),
         {:ok, multipart_upload} <-
           Storage.initiate_multipart_upload(
             storage,
             bucket,
             object_config.key,
             options
           ),
         params <- Map.put(params, :upload_id, multipart_upload.upload_id),
         {:ok, schema_data} <- actions_create(schema, params, options) do
      {:ok,
       Map.merge(object_config, %{
         multipart_upload: multipart_upload,
         schema_data: schema_data
       })}
    end
  end

  def move_temporary_to_permanent_upload(
        %Core{} = core,
        params,
        pipeline,
        options \\ []
      ) do
    with {:ok, schema_data} <-
           find_completed_upload(core, params, options),
         {:ok, owner} <-
           find_schema_data_owner(core, schema_data, options),
         object_config <-
           permanent_object_config(core, schema_data, owner),
         {:ok, pipeline} <-
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
         pipeline: pipeline,
         schema_data: schema_data,
         owner: owner
       })}
    end
  end

  defp permanent_object_config(
         %Core{
           resource: resource,
           permanent_object_key: permanent_object_key,
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
        permanent_object_key,
        resource: resource,
        basename: basename,
        id: owner_partition(owner, owner_partition_source)
      )

    %{
      basename: basename,
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

    with {:ok, result, done} <- Pipeline.run(input, pipeline) do
      {:ok, %{result: result, phases: done}}
    end
  end

  def complete_upload(
        %Core{
          bucket: bucket,
          storage: storage,
          queryable: schema
        } = core,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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
           Storage.head_object(storage, bucket, key, options),
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

  def garbage_collect_object(
        %Core{
          bucket: bucket,
          storage: storage,
          queryable: schema
        },
        key,
        options \\ []
      ) do
    with :ok <- ensure_not_found(schema, %{key: key}, options),
         {:ok, _} <- Storage.head_object(storage, bucket, key, options),
         {:ok, _} <- Storage.delete_object(storage, bucket, key, options) do
      :ok
    else
      {:error, %{code: :not_found}} -> :ok
      error -> error
    end
  end

  defp ensure_not_found(schema, params, options) do
    case actions_find(schema, params, options) do
      {:ok, schema_data} ->
        details = %{
          schema: schema,
          params: params,
          schema_data: schema_data
        }

        {:error, Error.call(:forbidden, "record found", details, options)}

      {:error, %{code: :not_found}} ->
        :ok

      error ->
        error
    end
  end

  @doc """
  ...
  """
  def abort_upload(%Core{queryable: schema} = core, params, options \\ []) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options),
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

  def find_permanent_upload(
        %Core{
          resource: resource,
          queryable: schema,
          permanent_object_key: permanent_object_key,
          owner_partition_source: owner_partition_source
        } = core,
        params,
        options
      ) do
    with {:ok, schema_data} <- actions_find(schema, params, options),
         key <- fetch_non_nil!(schema_data, :key),
         {:ok, owner} <- find_schema_data_owner(core, schema_data, options) do
      if ObjectKey.path?(
           permanent_object_key,
           id: owner_partition(owner, owner_partition_source),
           resource: resource,
           key: key
         ) do
        {:ok, %{schema_data: schema_data, owner: owner}}
      else
        details = %{query: schema, params: params}

        {:error, Error.call(:forbidden, "permanent upload not found", details, options)}
      end
    end
  end

  def find_completed_upload(
        %Core{queryable: schema} = core,
        params,
        options
      ) do
    with {:ok, schema_data} <- find_temporary_upload(core, params, options) do
      if is_binary(schema_data.e_tag) do
        {:ok, schema_data}
      else
        details = %{query: schema, params: params}

        {:error, Error.call(:forbidden, "upload incomplete", details, options)}
      end
    end
  end

  @doc """
  ...
  """
  def find_temporary_upload(
        %Core{
          queryable: schema,
          temporary_object_key: temporary_object_key
        },
        params,
        options
      ) do
    with {:ok, schema_data} <- actions_find(schema, params, options) do
      key = fetch_non_nil!(schema_data, :key)

      if ObjectKey.path?(temporary_object_key, key: key) do
        {:ok, schema_data}
      else
        details = %{query: schema, params: params}

        {:error, Error.call(:not_found, "temporary upload not found", details, options)}
      end
    end
  end

  def start_upload(
        %Core{
          bucket: bucket,
          storage: storage,
          queryable: schema,
          owner_association_source: owner_association_source,
          temporary_object_key: temporary_object_key,
          parent_association_source: parent_association_source
        },
        upload_params,
        params,
        options \\ []
      ) do
    assoc_id = upload_params[:assoc_id]
    owner_id = upload_params.owner_id

    filename = Map.fetch!(params, :filename)

    object_config =
      temporary_object_config(
        temporary_object_key,
        owner_id,
        filename,
        options
      )

    params =
      params
      |> Map.merge(%{
        key: object_config.key,
        unique_identifier: object_config.unique_identifier,
        filename: filename
      })
      |> Map.put(owner_association_source, owner_id)
      |> Map.put(parent_association_source, assoc_id)

    with :ok <- maybe_validate_filename(filename, options),
         {:ok, presigned_upload} <-
           Storage.presigned_upload(
             storage,
             bucket,
             object_config.key,
             options
           ),
         {:ok, schema_data} <- actions_create(schema, params, options) do
      {:ok,
       Map.merge(object_config, %{
         presigned_upload: presigned_upload,
         schema_data: schema_data
       })}
    end
  end

  defp temporary_object_config(temporary_object_key, owner_id, filename, options) do
    unique_identifier = generate_unique_identifier(options)
    basename = basename(unique_identifier, filename)

    key =
      ObjectKey.build(
        temporary_object_key,
        id: "#{owner_id}",
        basename: basename
      )

    %{
      basename: basename,
      unique_identifier: unique_identifier,
      key: key
    }
  end

  defp find_schema_data_owner(
         %Core{
           owner_schema: owner_schema,
           owner_association_source: owner_association_source
         },
         schema_data,
         options
       ) do
    owner_id = Map.fetch!(schema_data, owner_association_source)

    actions_find(owner_schema, %{owner_association_source => owner_id}, options)
  end

  defp owner_partition(owner, partition_source) do
    if is_nil(partition_source) or partition_source === false do
      @default_owner_partition
    else
      owner
      |> fetch_non_nil!(partition_source)
      |> to_string()
    end
  end

  defp generate_unique_identifier(options) do
    hash_length = Keyword.get(options, :hash_length, @default_hash_length)

    Utils.generate_unique_identifier(hash_length)
  end

  defp basename(unique_identifier, path) do
    "#{unique_identifier}-#{path}"
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

  defp maybe_validate_filename(filename, options) do
    web_safe_filename_enabled? =
      Keyword.get(
        options,
        :web_safe_filename_enabled,
        Config.web_safe_filename_enabled()
      )

    regex = Utils.web_safe_filename_regex()

    if web_safe_filename_enabled? and Regex.match?(regex, filename) do
      :ok
    else
      details = %{filename: filename, regex: regex}

      {:error,
       Error.call(:forbidden, "filename can only contain web safe characters", details, options)}
    end
  end

  # This is a convenience when fetching data from maps that may contain keys
  # that have nil values (ie. structs). This exists to provide early warning
  # when the next function could fail due to a nil argument.
  defp fetch_non_nil!(map, key) do
    case Map.get(map, key) do
      nil -> raise "value for `#{key}` cannot be nil, got:\n\n#{inspect(map, pretty: true)}"
      value -> value
    end
  end
end
