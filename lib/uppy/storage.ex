defmodule Uppy.Storage do
  @moduledoc """
  This module provides a standardized api for creating
  interfaces for storage services such as Amazon S3,
  Google Cloud, and Cloudfront.

  The following adapters are available:

    * `Uppy.Storages.S3` - Amazon S3

  ## Getting Started

  To create a storage adapter you must add the behaviour
  to your module:

  ```elixir
  defmodule YourApp.SomeModule do
    # Add the following line
    @behaviour Uppy.Storage
  end
  ```

  ## Shared Options

  All the functions outlined in this module accept the
  following options:

    * `:adapter` - A module that implements the behaviour
      `Uppy.Storage`.

    * `:storage` - A keyword list.

      * `:sandbox` - A boolean. When `true` the sandbox
        is used during tests otherwise when `false` all
        requests are sent to the live service.

  ## Sandbox / Testing

  This API provides a sandbox that returns mock responses
  for the functions defined in this module during testing.
  By using this sandbox, you can simulate the behavior of
  the live service.

  The sandbox is enabled by default during tests, if this
  behaviour is not desired you can set the `sandbox`
  storage option (`[storage: [sandbox: false]]`) to
  disable the sandbox.

  The sandbox functions are available when the mix env is
  `:test` only.

  ### Getting Started

  Add the following to your `test_helper.exs` file:

  ```elixir
  # test_helper.exs
  Uppy.Support.StorageSandbox.start_link()
  ```
  """
  alias Uppy.Config

  @type error_message :: ErrorMessage.t() | term()

  @typedoc "A module."
  @type adapter :: atom()

  @typedoc "A keyword list."
  @type opts :: keyword()

  @typedoc "Data sent during the HTTP request."
  @type body :: term()

  @typedoc "An HTTP request method."
  @type http_method :: :get | :post | :put | :patch | :delete | :head | :options

  @typedoc "A HTTP header."
  @type header :: {binary(), binary()}

  @typedoc "A list of HTTP headers."
  @type headers :: list(header())

  @typedoc "A HTTP status code."
  @type status_code :: non_neg_integer()

  @typedoc "The container used to store and organize objects."
  @type bucket :: binary()

  @typedoc "A tuple with the the part number and e_tag of the part that were uploaded."
  @type completed_part :: {part_number :: part_number(), e_tag :: e_tag()}

  @typedoc "A list of completed parts."
  @type completed_parts :: list(completed_part())

  @typedoc "The total size of the object in bytes."
  @type content_length :: non_neg_integer()

  @typedoc "The MIME type of the object, specifying its file type."
  @type content_type :: binary()

  @typedoc "A unique identifier for the current version of the object within a bucket."
  @type e_tag :: binary()

  @typedoc "A datetime."
  @type expires_at :: DateTime.t()

  @typedoc "The unique identifier for the object within the bucket."
  @type key :: binary()

  @typedoc "The timestamp when the object was last modified."
  @type last_modified :: DateTime.t()

  @typedoc "The URI that identifies the newly created object."
  @type location :: binary()

  @typedoc "A unique identifier for an object within a bucket."
  @type object :: binary()

  @typedoc "A unique integer that identifies each part of an object being uploaded as part of the multipart upload."
  @type part_number :: pos_integer()

  @typedoc "A string that objects must start with to be included in the result."
  @type prefix :: binary()

  @typedoc "Total size of the object in bytes."
  @type size :: non_neg_integer()

  @typedoc "A unique identifier for an initiated multipart upload."
  @type upload_id :: binary()

  @typedoc "A string."
  @type url :: binary()

  @type list_object_content :: %{
          e_tag: e_tag(),
          key: key(),
          last_modified: last_modified(),
          owner: binary() | nil,
          size: size(),
          storage_class: binary()
        }

  @type list_objects_response :: %{
          name: binary(),
          prefix: binary(),
          contents: list(list_object_content()),
          marker: binary(),
          max_keys: integer(),
          is_truncated: true | false,
          common_prefixes: list(),
          next_marker: binary(),
          key_count: integer(),
          next_continuation_token: binary()
        }

  @type get_object_payload :: term()

  @type head_object_payload :: %{
          content_length: content_length(),
          content_type: content_type(),
          e_tag: e_tag(),
          last_modified: last_modified()
        }

  @type delete_object_payload :: %{
          body: body(),
          headers: headers(),
          status_code: status_code()
        }

  @type put_object_payload :: %{
          body: body(),
          headers: headers(),
          status_code: status_code()
        }

  @type put_object_copy_payload :: %{
          body: body(),
          headers: headers(),
          status_code: status_code()
        }

  @type sign_part_payload :: %{
          expires_at: expires_at(),
          key: key(),
          url: url()
        }

  @type pre_sign_payload :: %{
          expires_at: expires_at(),
          key: key(),
          url: url()
        }

  @type abort_multipart_upload_payload :: %{
          body: body(),
          headers: headers(),
          status_code: status_code()
        }

  @type complete_multipart_upload_payload :: %{
          bucket: bucket(),
          e_tag: e_tag(),
          key: key(),
          location: location()
        }

  @type create_multipart_upload_payload :: %{
          bucket: bucket(),
          key: key(),
          upload_id: upload_id()
        }

  @type list_parts_payload ::
          list(%{
            e_tag: e_tag(),
            part_number: part_number(),
            size: size()
          })

  @type list_multipart_uploads_payload :: %{
          optional(atom()) => any(),
          bucket: bucket()
        }

  @doc """
  Returns all `objects` in a `bucket` matching `prefix`.

  Returns `{:ok, list(map())}` on success.

  Each map includes the keys:

    * `:bucket` - The container used to store and organize objects.

    * `:e_tag` - A unique identifier for the current version of the object.

    * `:key` -  The unique identifier for the object within the bucket.

    * `:last_modified` - The timestamp when the object was last modified.

    * `:size` - The size of object in bytes.

  Returns `{:error, term()}` on failure.
  """
  @callback list_objects(bucket :: bucket(), prefix :: prefix(), opts :: opts()) ::
              {:ok, list_objects_response()} | {:error, error_message()}

  @doc """
  Retrieves an `object`.

  Returns `{:ok, data()}` on success.

  The data is the downloaded content of the object.

  Returns `{:error, term()}` on failure.
  """
  @callback get_object(bucket :: bucket(), object :: object(), opts :: opts()) ::
              {:ok, get_object_payload()} | {:error, error_message()}

  @doc """
  Retrieves `metadata` from an `object` without returning the `object` itself.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:content_length` - The total size of the object in bytes.

    * `:content_type` - The MIME type of the object, specifying its file type.

    * `:e_tag` - A unique identifier for the current version of the object.

    * `:last_modified` - The timestamp when the object was last modified.

  Returns `{:error, term()}` on failure.
  """
  @callback head_object(bucket :: bucket(), object :: object(), opts :: opts()) ::
              {:ok, head_object_payload()} | {:error, error_message()}

  @doc """
  Removes an object from a bucket.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:body` - The body of the HTTP request.

    * `:headers` - A list of HTTP header tuples.

    * `:status_code` - An HTTP status code (eg. 204).

  Returns `{:error, term()}` on failure.
  """
  @callback delete_object(
              bucket :: bucket(),
              object :: object(),
              opts :: opts()
            ) :: {:ok, delete_object_payload()} | {:error, error_message()}

  @doc """
  Uploads an entire object to a bucket.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

  * `:body` - The body of the HTTP request.

  * `:headers` - A list of HTTP header tuples.

  * `:status_code` - An HTTP status code (eg. 204).

  Returns `{:error, term()}` on failure.
  """
  @callback put_object(
              bucket :: bucket(),
              object :: object(),
              body :: body(),
              opts :: opts()
            ) :: {:ok, put_object_payload()} | {:error, error_message()}

  @doc """
  Creates a copy of an object that is already stored.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:body` - The body of the HTTP request.

    * `:headers` - A list of HTTP header tuples.

    * `:status_code` - An HTTP status code (eg. 204).

  Returns `{:error, term()}` on failure.
  """
  @callback put_object_copy(
              destination_bucket :: bucket(),
              destination_object :: object(),
              source_bucket :: bucket(),
              source_object :: object(),
              opts :: opts()
            ) :: {:ok, put_object_copy_payload()} | {:error, error_message()}

  @doc """
  Generate a pre-signed URL for an object.

  This is a temporary link that allows access to a specific resource in the
  `bucket` without requiring direct permissions.

  It can be used to upload or download content.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:expires_at` - The timestamp when access expires.

    * `:key` - The unique identifier for the object within the bucket.

    * `:url` - The pre-signed URL.

  Returns `{:error, term()}` on failure.
  """
  @callback sign_part(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              part_number :: part_number(),
              opts :: opts()
            ) :: {:ok, sign_part_payload()} | {:error, error_message()}

  @doc """
  Generate a pre-signed URL for an object.

  This is a temporary link that allows access to a specific resource in the
  `bucket` without requiring direct permissions.

  It can be used to upload or download content.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:expires_at` - The timestamp when access expires.

    * `:key` - The unique identifier for the object within the bucket.

    * `:url` - The pre-signed URL.

  Returns `{:error, term()}` on failure.
  """
  @callback pre_sign(
              bucket :: bucket(),
              http_method :: http_method(),
              object :: object(),
              opts :: opts()
            ) :: {:ok, pre_sign_payload()} | {:error, error_message()}

  @doc """
  Retrieves in-progress multipart uploads in a `bucket`.

  An in-progress multipart upload is a multipart upload that
  has been initiated by `create_multipart_upload/3`, but has
  not yet been completed or aborted.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:bucket` - The container used to store and organize objects.

  Returns `{:error, term()}` on failure.
  """
  @callback list_multipart_uploads(bucket :: bucket(), opts :: opts()) ::
              {:ok, list_multipart_uploads_payload()} | {:error, error_message()}

  @doc """
  Initiates a multipart upload.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:bucket` - The container used to store and organize objects.

    * `:key` -  The unique identifier for the object within the bucket.

    * `:upload_id` - The `upload_id` is used to associate all of the
    parts in the specific multipart upload. The `upload_id` must be
    given to each subsequent upload part request (see `sign_part/5`).

    The `upload_id` must also be included in the request to either
    complete or abort the multipart upload.

  Returns `{:error, term()}` on failure.
  """
  @callback create_multipart_upload(bucket :: bucket(), object :: object(), opts :: opts()) ::
              {:ok, create_multipart_upload_payload()} | {:error, error_message()}

  @doc """
  Retrieves the parts that have been uploaded for a multipart upload.

  To use this operation the `upload_id` returned by
  `create_multipart_upload/3` must be provided.

  Returns `{:ok, list(map())}` on success.

  Each map includes the keys:

    * `:e_tag` - A unique identifier for the current version of the object.

    * `:part_number` - A unique integer that identifies each part of
      an object being uploaded as part of the multipart upload.

    * `:size` - The size of object in bytes.

  Returns `{:error, term()}` on failure.
  """
  @callback list_parts(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              opts :: opts()
            ) :: {:ok, list_parts_payload()} | {:error, error_message()}

  @doc """
  Aborts a multipart upload.

  To use this operation the `upload_id` returned by
  `create_multipart_upload/3` must be provided.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:body` - The body of the HTTP request.

    * `:headers` - A list of HTTP header tuples.

    * `:status_code` - An HTTP status code (eg. 204).

  Returns `{:error, term()}` on failure.
  """
  @callback abort_multipart_upload(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              opts :: opts()
            ) :: {:ok, abort_multipart_upload_payload()} | {:error, error_message()}

  @doc """
  Completes a multipart upload given previously uploaded parts.

  To use this operation the `upload_id` returned by
  `create_multipart_upload/3` must be provided.

  Returns `{:ok, map()}` on success.

  The map includes the keys:

    * `:bucket` - The container used to store and organize objects.

    * `:e_tag` - A unique identifier for the current version of the object.

    * `:key` -  The unique identifier for the object within the bucket.

    * `:location` - The URI that identifies the newly created object.

  Returns `{:error, term()}` on failure.
  """
  @callback complete_multipart_upload(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              parts :: completed_parts(),
              opts :: opts()
            ) :: {:ok, complete_multipart_upload_payload()} | {:error, error_message()}

  @default_adapter Uppy.Storages.S3

  @default_opts [
    storage_adapter: @default_adapter,
    storage: [
      sandbox: Mix.env() === :test
    ]
  ]

  def object_chunk_stream(bucket, object, chunk_size, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_object_chunk_stream_response(bucket, object, chunk_size, opts)
    else
      bucket
      |> adapter!(opts).object_chunk_stream(object, chunk_size, opts)
      |> handle_response()
    end
  end

  def get_chunk(bucket, object, start_byte, end_byte, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts)
    else
      bucket
      |> adapter!(opts).get_chunk(object, start_byte, end_byte, opts)
      |> handle_response()
    end
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.list_objects/3`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.list_objects("your_bucket")
  """
  @spec list_objects(bucket :: bucket()) ::
          {:ok, list_objects_response()} | {:error, error_message()}
  @spec list_objects(bucket :: bucket(), prefix :: prefix()) ::
          {:ok, list_objects_response()} | {:error, error_message()}
  @spec list_objects(bucket :: bucket(), prefix :: prefix(), opts :: opts()) ::
          {:ok, list_objects_response()} | {:error, error_message()}
  def list_objects(bucket, prefix \\ "", opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_list_objects_response(bucket, prefix, opts)
    else
      bucket
      |> adapter!(opts).list_objects(prefix, opts)
      |> handle_response()
    end
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.get_object/3`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.get_object("your_bucket", "example.txt")
  """
  @spec get_object(
          bucket :: bucket(),
          object :: object()
        ) :: {:ok, get_object_payload()} | {:error, error_message()}
  @spec get_object(
          bucket :: bucket(),
          object :: object(),
          opts :: opts()
        ) :: {:ok, get_object_payload()} | {:error, error_message()}
  def get_object(bucket, object, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_get_object_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).get_object(object, opts)
      |> handle_response()
    end
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.get_object/3`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.head_object("your_bucket", "example.txt")
  """
  @spec head_object(
          bucket :: bucket(),
          object :: object()
        ) :: {:ok, head_object_payload()} | {:error, error_message()}
  @spec head_object(
          bucket :: bucket(),
          object :: object(),
          opts :: opts()
        ) :: {:ok, head_object_payload()} | {:error, error_message()}
  def head_object(bucket, object, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    if sandbox? && !sandbox_disabled?() do
      sandbox_head_object_response(bucket, object, opts)
    else
      bucket
      |> adapter!(opts).head_object(object, opts)
      |> handle_response()
    end
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.put_object/4`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.put_object("your_bucket", "example.txt", "Hello world!")
  """
  @spec put_object(
          bucket :: bucket(),
          object :: object(),
          body :: body()
        ) :: {:ok, put_object_payload()} | {:error, error_message()}
  @spec put_object(
          bucket :: bucket(),
          object :: object(),
          body :: body(),
          opts :: opts()
        ) :: {:ok, put_object_payload()} | {:error, error_message()}
  def put_object(bucket, object, body, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_put_object_response(bucket, object, body, opts)
      else
        adapter!(opts).put_object(bucket, object, body, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.put_object_copy/4`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.put_object_copy("your_bucket", "example.txt", "Hello world!")
  """
  @spec put_object_copy(
          destination_bucket :: bucket(),
          destination_object :: object(),
          source_bucket :: bucket(),
          source_object :: object()
        ) :: {:ok, put_object_copy_payload()} | {:error, error_message()}
  @spec put_object_copy(
          destination_bucket :: bucket(),
          destination_object :: object(),
          source_bucket :: bucket(),
          source_object :: object(),
          opts :: opts()
        ) :: {:ok, put_object_copy_payload()} | {:error, error_message()}
  def put_object_copy(
        destination_bucket,
        destination_object,
        source_bucket,
        source_object,
        opts \\ []
      ) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_put_object_copy_response(
          destination_bucket,
          destination_object,
          source_bucket,
          source_object,
          opts
        )
      else
        adapter!(opts).put_object_copy(
          destination_bucket,
          destination_object,
          source_bucket,
          source_object,
          opts
        )
      end

    handle_response(response)
  end

  @doc """
  ...
  """
  @spec delete_object(
          bucket :: bucket(),
          object :: object(),
          opts :: opts()
        ) :: {:ok, term()} | {:error, error_message()}
  def delete_object(bucket, object, opts) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_delete_object_response(bucket, object, opts)
      else
        adapter!(opts).delete_object(bucket, object, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.sign_part/5`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.sign_part("your_bucket", "example.txt", "upload_id", 1)
  """
  @spec sign_part(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          part_number :: part_number()
        ) :: {:ok, sign_part_payload()} | {:error, error_message()}
  @spec sign_part(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          part_number :: part_number(),
          opts :: opts()
        ) :: {:ok, sign_part_payload()} | {:error, error_message()}
  def sign_part(
        bucket,
        object,
        upload_id,
        part_number,
        opts \\ []
      ) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_sign_part_response(bucket, object, upload_id, part_number, opts)
      else
        adapter!(opts).sign_part(bucket, object, upload_id, part_number, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.pre_sign/4`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.pre_sign("your_bucket", :put, "example.txt")
  """
  @spec pre_sign(
          bucket :: bucket(),
          http_method :: http_method(),
          object :: object()
        ) :: {:ok, pre_sign_payload()} | {:error, error_message()}
  @spec pre_sign(
          bucket :: bucket(),
          http_method :: http_method(),
          object :: object(),
          opts :: opts()
        ) :: {:ok, pre_sign_payload()} | {:error, error_message()}
  def pre_sign(bucket, http_method, object, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_pre_sign_response(bucket, http_method, object, opts)
      else
        adapter!(opts).pre_sign(bucket, http_method, object, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.list_multipart_uploads/2`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.list_multipart_uploads("your_bucket")
  """
  @spec list_multipart_uploads(bucket :: bucket()) ::
          {:ok, list_multipart_uploads_payload()} | {:error, error_message()}
  @spec list_multipart_uploads(bucket :: bucket(), opts :: opts()) ::
          {:ok, list_multipart_uploads_payload()} | {:error, error_message()}
  def list_multipart_uploads(bucket, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_list_multipart_uploads_response(bucket, opts)
      else
        adapter!(opts).list_multipart_uploads(bucket, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.create_multipart_upload/3`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.create_multipart_upload("your_bucket", "example.txt")
  """
  @spec create_multipart_upload(
          bucket :: bucket(),
          object :: object()
        ) :: {:ok, create_multipart_upload_payload()} | {:error, error_message()}
  @spec create_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          opts :: opts()
        ) :: {:ok, create_multipart_upload_payload()} | {:error, error_message()}
  def create_multipart_upload(bucket, object, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_create_multipart_upload_response(bucket, object, opts)
      else
        adapter!(opts).create_multipart_upload(bucket, object, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.list_parts/4`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.list_parts("your_bucket", "example.txt", "upload_id")
  """
  @spec list_parts(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id()
        ) :: {:ok, list_parts_payload()} | {:error, error_message()}
  @spec list_parts(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          opts :: opts()
        ) :: {:ok, list_parts_payload()} | {:error, error_message()}
  def list_parts(bucket, object, upload_id, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_list_parts_response(bucket, object, upload_id, opts)
      else
        adapter!(opts).list_parts(bucket, object, upload_id, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.abort_multipart_upload/4`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.abort_multipart_upload("your_bucket", "example.txt", "upload_id")
  """
  @spec abort_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id()
        ) :: {:ok, abort_multipart_upload_payload()} | {:error, error_message()}
  @spec abort_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          opts :: opts()
        ) :: {:ok, abort_multipart_upload_payload()} | {:error, error_message()}
  def abort_multipart_upload(bucket, object, upload_id, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts)
      else
        adapter!(opts).abort_multipart_upload(bucket, object, upload_id, opts)
      end

    handle_response(response)
  end

  @doc """
  Executes the callback function `c:Uppy.Storage.complete_multipart_upload/5`.

  ### Options

  See `Uppy.Storage` module documentation for more options.

  ### Examples

      iex> Uppy.Storage.complete_multipart_upload("your_bucket", "example.txt", "upload_id", [{1, "e_tag"}])
  """
  @spec complete_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          parts :: completed_parts()
        ) :: {:ok, complete_multipart_upload_payload()} | {:error, error_message()}
  @spec complete_multipart_upload(
          bucket :: bucket(),
          object :: object(),
          upload_id :: upload_id(),
          parts :: completed_parts(),
          opts :: opts()
        ) :: {:ok, complete_multipart_upload_payload()} | {:error, error_message()}
  def complete_multipart_upload(bucket, object, upload_id, parts, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sandbox? = opts[:storage][:sandbox]

    response =
      if sandbox? && !sandbox_disabled?() do
        sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, opts)
      else
        adapter!(opts).complete_multipart_upload(bucket, object, upload_id, parts, opts)
      end

    handle_response(response)
  end

  defp adapter!(opts) do
    opts[:storage_adapter] || Config.storage_adapter() || @default_adapter
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, _} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    - {:ok, term()}

    - {:error, error_message()}

    got:

    #{inspect(term, pretty: true)}
    """
  end

  if Mix.env() === :test do
    defdelegate sandbox_object_chunk_stream_response(bucket, object, chunk_size, opts),
      to: Uppy.Support.StorageSandbox,
      as: :object_chunk_stream_response

    defdelegate sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts),
      to: Uppy.Support.StorageSandbox,
      as: :get_chunk_response

    defdelegate sandbox_list_objects_response(bucket, prefix, opts),
      to: Uppy.Support.StorageSandbox,
      as: :list_objects_response

    defdelegate sandbox_get_object_response(bucket, object, opts),
      to: Uppy.Support.StorageSandbox,
      as: :get_object_response

    defdelegate sandbox_head_object_response(bucket, object, opts),
      to: Uppy.Support.StorageSandbox,
      as: :head_object_response

    defdelegate sandbox_delete_object_response(bucket, object, opts),
      to: Uppy.Support.StorageSandbox,
      as: :delete_object_response

    defdelegate sandbox_put_object_response(bucket, object, body, opts),
      to: Uppy.Support.StorageSandbox,
      as: :put_object_response

    defdelegate sandbox_put_object_copy_response(
                  destination_bucket,
                  destination_object,
                  source_bucket,
                  source_object,
                  opts
                ),
                to: Uppy.Support.StorageSandbox,
                as: :put_object_copy_response

    defdelegate sandbox_sign_part_response(bucket, object, upload_id, part_number, opts),
      to: Uppy.Support.StorageSandbox,
      as: :sign_part_response

    defdelegate sandbox_pre_sign_response(bucket, method, object, opts),
      to: Uppy.Support.StorageSandbox,
      as: :pre_sign_response

    defdelegate sandbox_list_multipart_uploads_response(bucket, opts),
      to: Uppy.Support.StorageSandbox,
      as: :list_multipart_uploads_response

    defdelegate sandbox_create_multipart_upload_response(bucket, object, opts),
      to: Uppy.Support.StorageSandbox,
      as: :create_multipart_upload_response

    defdelegate sandbox_list_parts_response(
                  bucket,
                  object,
                  upload_id,
                  opts
                ),
                to: Uppy.Support.StorageSandbox,
                as: :list_parts_response

    defdelegate sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts),
      to: Uppy.Support.StorageSandbox,
      as: :abort_multipart_upload_response

    defdelegate sandbox_complete_multipart_upload_response(
                  bucket,
                  object,
                  upload_id,
                  parts,
                  opts
                ),
                to: Uppy.Support.StorageSandbox,
                as: :complete_multipart_upload_response

    defdelegate sandbox_disabled?, to: Uppy.Support.StorageSandbox
  else
    defp sandbox_object_chunk_stream_response(bucket, object, chunk_size, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      chunk_size: #{inspect(chunk_size)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_get_chunk_response(bucket, object, start_byte, end_byte, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      start_byte: #{inspect(start_byte)}
      end_byte: #{inspect(end_byte)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_objects_response(bucket, prefix, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      prefix: #{prefix}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_get_object_response(bucket, object, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_head_object_response(bucket, object, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_delete_object_response(bucket, object, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_put_object_response(bucket, object, body, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      body: #{inspect(body)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_put_object_copy_response(
           destination_bucket,
           destination_object,
           source_bucket,
           source_object,
           opts
         ) do
      raise """
      Cannot use sandbox outside of test

      destination_bucket: #{inspect(destination_bucket)}
      destination_object: #{inspect(destination_object)}
      source_bucket: #{inspect(source_bucket)}
      source_object: #{inspect(source_object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_sign_part_response(bucket, object, upload_id, part_number, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      part_number: #{inspect(part_number)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_pre_sign_response(bucket, method, object, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      method: #{inspect(method)}
      object: #{inspect(object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_multipart_uploads_response(bucket, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_create_multipart_upload_response(bucket, object, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_list_parts_response(bucket, object, upload_id, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_abort_multipart_upload_response(bucket, object, upload_id, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_complete_multipart_upload_response(bucket, object, upload_id, parts, opts) do
      raise """
      Cannot use sandbox outside of test

      bucket: #{inspect(bucket)}
      object: #{inspect(object)}
      upload_id: #{inspect(upload_id)}
      parts: #{inspect(parts, pretty: true)}
      options: #{inspect(opts, pretty: true)}
      """
    end

    defp sandbox_disabled?, do: true
  end
end
