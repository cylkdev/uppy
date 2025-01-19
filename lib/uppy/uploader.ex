defmodule Uppy.Uploader do
  alias Uppy.{
    Core,
    DBAction
  }

  def all(adapter, params, opts \\ []) do
    DBAction.all(adapter.query(), params, opts)
  end

  def create(adapter, params, opts \\ []) do
    DBAction.create(adapter.query(), params, opts)
  end

  def find(adapter, params, opts \\ []) do
    DBAction.find(adapter.query(), params, opts)
  end

  def update(adapter, find_params_or_struct, update_params, opts \\ []) do
    DBAction.update(adapter.query(), find_params_or_struct, update_params, opts)
  end

  def delete(adapter, id_or_struct, opts \\ []) do
    DBAction.delete(adapter.query(), id_or_struct, opts)
  end

  def move_to_destination(
        adapter,
        destination_object,
        find_params_or_struct,
        opts \\ []
      ) do
    Core.move_to_destination(
      adapter.bucket(),
      destination_object,
      adapter.query(),
      find_params_or_struct,
      opts
    )
  end

  def find_parts(
        adapter,
        find_params_or_struct,
        opts \\ []
      ) do
    Core.find_parts(
      adapter.bucket(),
      adapter.query(),
      find_params_or_struct,
      opts
    )
  end

  def sign_part(
        adapter,
        find_params_or_struct,
        part_number,
        opts \\ []
      ) do
    Core.sign_part(
      adapter.bucket(),
      adapter.query(),
      find_params_or_struct,
      part_number,
      opts
    )
  end

  def complete_multipart_upload(
        adapter,
        find_params_or_struct,
        builder_params,
        update_params,
        parts,
        opts \\ []
      ) do
    Core.complete_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      builder_params,
      find_params_or_struct,
      update_params,
      parts,
      opts
    )
  end

  def abort_multipart_upload(
        adapter,
        find_params_or_struct,
        update_params,
        opts \\ []
      ) do
    Core.abort_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      find_params_or_struct,
      update_params,
      opts
    )
  end

  def create_multipart_upload(adapter, filename, builder_params, create_params, opts \\ []) do
    Core.create_multipart_upload(
      adapter.bucket(),
      adapter.query(),
      filename,
      builder_params,
      create_params,
      opts
    )
  end

  def complete_upload(adapter, builder_params, find_params_or_struct, update_params, opts \\ []) do
    Core.complete_upload(
      adapter.bucket(),
      adapter.query(),
      builder_params,
      find_params_or_struct,
      update_params,
      opts
    )
  end

  def abort_upload(
        adapter,
        find_params_or_struct,
        update_params,
        opts \\ []
      ) do
    Core.abort_upload(
      adapter.bucket(),
      adapter.query(),
      find_params_or_struct,
      update_params,
      opts
    )
  end

  def create_upload(adapter, filename, builder_params, create_params, opts \\ []) do
    Core.create_upload(
      adapter.bucket(),
      adapter.query(),
      filename,
      builder_params,
      create_params,
      opts
    )
  end

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      @bucket opts[:bucket]
      @query opts[:query]
      @default_opts opts[:options]

      def bucket, do: @bucket

      def query, do: @query

      def all(params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.all(
          __MODULE__,
          params,
          opts
        )
      end

      def create(params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.create(
          __MODULE__,
          params,
          opts
        )
      end

      def find(params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.find(
          __MODULE__,
          params,
          opts
        )
      end

      def update(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.update(
          __MODULE__,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def delete(id_or_struct, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.delete(
          __MODULE__,
          id_or_struct,
          opts
        )
      end

      def move_to_destination(destination_object, find_params_or_struct, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.move_to_destination(
          __MODULE__,
          destination_object,
          find_params_or_struct,
          opts
        )
      end

      def complete_multipart_upload(
            find_params_or_struct,
            update_params,
            parts,
            builder_params \\ %{},
            opts \\ []
          ) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.complete_multipart_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          parts,
          builder_params,
          opts
        )
      end

      def abort_multipart_upload(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.abort_multipart_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(filename, create_params, builder_params \\ %{}, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.create_multipart_upload(
          __MODULE__,
          filename,
          create_params,
          builder_params,
          opts
        )
      end

      def complete_upload(find_params_or_struct, update_params, builder_params \\ %{}, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.complete_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          builder_params,
          opts
        )
      end

      def abort_upload(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.abort_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(filename, create_params, builder_params \\ %{}, opts \\ []) do
        opts = Keyword.merge(@default_opts, opts)

        Uppy.UploaderTemplate.create_upload(
          __MODULE__,
          filename,
          create_params,
          builder_params,
          opts
        )
      end

      defoverridable create_upload: 3,
                     create_upload: 2,
                     abort_upload: 3,
                     abort_upload: 2,
                     complete_upload: 3,
                     complete_upload: 2,
                     create_multipart_upload: 3,
                     create_multipart_upload: 2,
                     abort_multipart_upload: 3,
                     abort_multipart_upload: 2,
                     complete_multipart_upload: 4,
                     complete_multipart_upload: 3,
                     move_to_destination: 3,
                     move_to_destination: 2
    end
  end
end
