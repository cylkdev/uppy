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
        object_desc,
        find_params_or_struct,
        update_params,
        parts,
        opts \\ []
      ) do
    Core.complete_multipart_upload(
      adapter.bucket(),
      object_desc,
      adapter.query(),
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

  def create_multipart_upload(adapter, object_desc, filename, create_params, opts \\ []) do
    Core.create_multipart_upload(
      adapter.bucket(),
      object_desc,
      adapter.query(),
      filename,
      create_params,
      opts
    )
  end

  def complete_upload(adapter, object_desc, find_params_or_struct, update_params, opts \\ []) do
    Core.complete_upload(
      adapter.bucket(),
      object_desc,
      adapter.query(),
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

  def create_upload(adapter, object_desc, filename, create_params, opts \\ []) do
    Core.create_upload(
      adapter.bucket(),
      object_desc,
      adapter.query(),
      filename,
      create_params,
      opts
    )
  end

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      @bucket opts[:bucket]
      @query opts[:query]
      @options opts[:options]

      @object_desc opts[:object_description] || %{}

      def bucket, do: @bucket

      def query, do: @query

      def options, do: @options

      def object_description, do: @object_desc

      def all(params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.all(__MODULE__, params, opts)
      end

      def create(params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.create(__MODULE__, params, opts)
      end

      def find(params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.find(__MODULE__, params, opts)
      end

      def update(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.update(__MODULE__, find_params_or_struct, update_params, opts)
      end

      def delete(id_or_struct, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.delete(__MODULE__, id_or_struct, opts)
      end

      def move_to_destination(destination_object, find_params_or_struct, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.move_to_destination(
          __MODULE__,
          destination_object,
          find_params_or_struct,
          opts
        )
      end

      def complete_multipart_upload(
            object_desc,
            find_params_or_struct,
            update_params,
            parts,
            opts \\ []
          ) do
        opts = Keyword.merge(@options, opts)

        object_desc = Map.merge(object_desc, @object_desc)

        Uppy.Uploader.complete_multipart_upload(
          __MODULE__,
          object_desc,
          find_params_or_struct,
          update_params,
          parts,
          opts
        )
      end

      def abort_multipart_upload(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.abort_multipart_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(filename, create_params, object_desc \\ %{}, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        object_desc = Map.merge(object_desc, @object_desc)

        Uppy.Uploader.create_multipart_upload(
          __MODULE__,
          object_desc,
          filename,
          create_params,
          opts
        )
      end

      def complete_upload(object_desc, find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        object_desc = Map.merge(object_desc, @object_desc)

        Uppy.Uploader.complete_upload(
          __MODULE__,
          object_desc,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def abort_upload(find_params_or_struct, update_params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        Uppy.Uploader.abort_upload(
          __MODULE__,
          find_params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(object_desc, filename, create_params, opts \\ []) do
        opts = Keyword.merge(@options, opts)

        object_desc = Map.merge(object_desc, @object_desc)

        Uppy.Uploader.create_upload(
          __MODULE__,
          object_desc,
          filename,
          create_params,
          opts
        )
      end
    end
  end
end
