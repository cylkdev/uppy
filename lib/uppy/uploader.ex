defmodule Uppy.Uploader do
  @moduledoc false
  alias Uppy.Core

  @callback bucket :: binary()

  @callback query :: atom() | {binary() | atom()}

  @callback path_builder_params(action :: atom(), params :: map()) :: map()

  @callback move_to_destination(
              dest_object :: binary(),
              params_or_struct :: map() | struct(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback find_parts(params_or_struct :: map() | struct(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback sign_part(
              params_or_struct :: map() | struct(),
              part_number :: non_neg_integer(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback complete_multipart_upload(
              builder_params :: any(),
              params_or_struct :: map() | struct(),
              update_params :: map(),
              parts :: list({part_number :: non_neg_integer(), e_tag :: binary()}),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback abort_multipart_upload(
              params_or_struct :: map() | struct(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback create_multipart_upload(
              builder_params :: any(),
              create_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback complete_upload(
              builder_params :: any(),
              params_or_struct :: map() | struct(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback abort_upload(
              params_or_struct :: map() | struct(),
              update_params :: map(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback create_upload(builder_params :: any(), create_params :: map(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  @optional_callbacks [path_builder_params: 2]

  @definition [
    bucket: [
      type: :string,
      required: true
    ],
    query: [
      type: {:or, [:atom, {:tuple, [:string, :atom]}]},
      required: true
    ]
  ]

  def definition, do: @definition

  def validate_definition!(opts), do: NimbleOptions.validate!(opts, @definition)

  def bucket(uploader), do: uploader.bucket()

  def query(uploader), do: uploader.query()

  def move_to_destination(uploader, dest_object, params_or_struct, opts) do
    Core.move_to_destination(
      uploader.bucket(),
      uploader.query(),
      dest_object,
      params_or_struct,
      opts
    )
  end

  def find_parts(uploader, params_or_struct, opts) do
    Core.find_parts(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      opts
    )
  end

  def sign_part(uploader, params_or_struct, part_number, opts) do
    Core.sign_part(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      part_number,
      opts
    )
  end

  def complete_multipart_upload(
        uploader,
        builder_params,
        params_or_struct,
        update_params,
        parts,
        opts
      ) do
    Core.complete_multipart_upload(
      uploader.bucket(),
      path_builder_params(uploader, :complete_multipart_upload, builder_params),
      uploader.query(),
      params_or_struct,
      update_params,
      parts,
      opts
    )
  end

  def abort_multipart_upload(uploader, params_or_struct, update_params, opts) do
    Core.abort_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def create_multipart_upload(uploader, builder_params, create_params, opts) do
    Core.create_multipart_upload(
      uploader.bucket(),
      path_builder_params(uploader, :create_multipart_upload, builder_params),
      uploader.query(),
      create_params,
      opts
    )
  end

  def complete_upload(uploader, builder_params, params_or_struct, update_params, opts) do
    Core.complete_upload(
      uploader.bucket(),
      path_builder_params(uploader, :complete_upload, builder_params),
      uploader.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def abort_upload(uploader, find_params, update_params, opts) do
    Core.abort_upload(
      uploader.bucket(),
      uploader.query(),
      find_params,
      update_params,
      opts
    )
  end

  def create_upload(uploader, builder_params, create_params, opts) do
    Core.create_upload(
      uploader.bucket(),
      path_builder_params(uploader, :create_upload, builder_params),
      uploader.query(),
      create_params,
      opts
    )
  end

  defp path_builder_params(uploader, action, params) do
    if function_exported?(uploader, :path_builder_params, 2) do
      uploader.path_builder_params(action, params)
    else
      params
    end
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      opts = Uppy.Uploader.validate_definition!(opts)

      alias Uppy.Uploader

      @behaviour Uppy.Uploader

      @bucket opts[:bucket]

      @query opts[:query]

      @impl true
      def bucket, do: @bucket

      @impl true
      def query, do: @query

      @impl true
      def move_to_destination(dest_object, params_or_struct, opts) do
        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          opts
        )
      end

      @impl true
      def find_parts(params_or_struct, opts) do
        Uploader.find_parts(__MODULE__, params_or_struct, opts)
      end

      @impl true
      def sign_part(params_or_struct, part_number, opts) do
        Uploader.sign_part(__MODULE__, params_or_struct, part_number, opts)
      end

      @impl true
      def complete_multipart_upload(
            builder_params,
            params_or_struct,
            update_params,
            parts,
            opts
          ) do
        Uploader.complete_multipart_upload(
          __MODULE__,
          builder_params,
          params_or_struct,
          update_params,
          parts,
          opts
        )
      end

      @impl true
      def abort_multipart_upload(params_or_struct, update_params, opts) do
        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      @impl true
      def create_multipart_upload(builder_params, create_params, opts) do
        Uploader.create_multipart_upload(
          __MODULE__,
          builder_params,
          create_params,
          opts
        )
      end

      @impl true
      def complete_upload(builder_params, params_or_struct, update_params, opts) do
        Uploader.complete_upload(
          __MODULE__,
          builder_params,
          params_or_struct,
          update_params,
          opts
        )
      end

      @impl true
      def abort_upload(params_or_struct, update_params, opts) do
        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      @impl true
      def create_upload(builder_params, create_params, opts) do
        Uploader.create_upload(
          __MODULE__,
          builder_params,
          create_params,
          opts
        )
      end

      defoverridable abort_upload: 3,
                     create_upload: 3,
                     complete_upload: 4,
                     abort_multipart_upload: 3,
                     create_multipart_upload: 3,
                     complete_multipart_upload: 5,
                     sign_part: 3,
                     find_parts: 2,
                     move_to_destination: 3
    end
  end
end
