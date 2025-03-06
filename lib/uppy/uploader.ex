defmodule Uppy.Uploader do
  @moduledoc false

  alias Uppy.Core

  def bucket(adapter), do: adapter.bucket()

  def query(adapter), do: adapter.query()

  def path_definition(adapter), do: adapter.path_definition()

  def options(adapter), do: adapter.options()

  def move_to_destination(adapter, dest_object, params_or_struct, opts \\ []) do
    Core.move_to_destination(
      adapter.bucket(),
      dest_object,
      adapter.query(),
      params_or_struct,
      opts
    )
  end

  def find_parts(adapter, params_or_struct, opts \\ []) do
    Core.find_parts(adapter.bucket(), adapter.query(), params_or_struct, opts)
  end

  def sign_part(adapter, params_or_struct, part_number, opts \\ []) do
    Core.sign_part(adapter.bucket(), adapter.query(), params_or_struct, part_number, opts)
  end

  def complete_multipart_upload(
        adapter,
        params_or_struct,
        update_params,
        parts,
        opts \\ []
      ) do
    Core.complete_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      params_or_struct,
      update_params,
      parts,
      opts
    )
  end

  def abort_multipart_upload(
        adapter,
        params_or_struct,
        update_params,
        opts \\ []
      ) do
    Core.abort_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def create_multipart_upload(adapter, filename, create_params, opts \\ []) do
    Core.create_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      filename,
      create_params,
      opts
    )
  end

  def complete_upload(adapter, params_or_struct, update_params, opts \\ []) do
    Core.complete_upload(
      adapter.bucket(),
      adapter.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def abort_upload(
        adapter,
        params_or_struct,
        update_params,
        opts \\ []
      ) do
    Core.abort_upload(
      adapter.bucket(),
      adapter.query(),
      params_or_struct,
      update_params,
      opts
    )
  end

  def create_upload(adapter, filename, create_params, opts \\ []) do
    Core.create_upload(
      adapter.bucket(),
      adapter.query(),
      filename,
      create_params,
      opts
    )
  end

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      alias Uppy.Uploader

      @bucket opts[:bucket]

      @query opts[:query]

      @default_opts opts[:options] || []

      def bucket, do: @bucket

      def query, do: @query

      def options, do: @default_opts

      def move_to_destination(dest_object, params_or_struct, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          opts
        )
      end

      def find_parts(params_or_struct, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.find_parts(__MODULE__, params_or_struct, opts)
      end

      def sign_part(params_or_struct, part_number, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.sign_part(__MODULE__, params_or_struct, part_number, opts)
      end

      def complete_multipart_upload(
            params_or_struct,
            update_params,
            parts,
            opts \\ []
          ) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.complete_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          parts,
          opts
        )
      end

      def abort_multipart_upload(params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(filename, create_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.create_multipart_upload(
          __MODULE__,
          filename,
          create_params,
          opts
        )
      end

      def complete_upload(params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.complete_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def abort_upload(params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(filename, create_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uploader.create_upload(
          __MODULE__,
          filename,
          create_params,
          opts
        )
      end

      defoverridable create_upload: 4,
                     abort_upload: 3,
                     complete_upload: 4,
                     create_multipart_upload: 4,
                     abort_multipart_upload: 3,
                     complete_multipart_upload: 5,
                     sign_part: 3,
                     find_parts: 2,
                     move_to_destination: 3
    end
  end
end
