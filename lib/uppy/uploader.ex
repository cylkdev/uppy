defmodule Uppy.Uploader do
  @moduledoc false
  alias Uppy.Core

  def bucket(uploader), do: uploader.bucket()

  def query(uploader), do: uploader.query()

  def resource_name(uploader), do: uploader.resource_name()

  def path(uploader), do: uploader.path()

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
        path_params,
        params_or_struct,
        update_params,
        parts,
        opts
      ) do
    Core.complete_multipart_upload(
      uploader.bucket(),
      build_object_path(uploader, path_params),
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

  def create_multipart_upload(uploader, path_params, create_params, opts) do
    Core.create_multipart_upload(
      uploader.bucket(),
      build_object_path(uploader, path_params),
      uploader.query(),
      create_params,
      opts
    )
  end

  def complete_upload(uploader, path_params, params_or_struct, update_params, opts) do
    Core.complete_upload(
      uploader.bucket(),
      build_object_path(uploader, path_params),
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

  def create_upload(uploader, path_params, create_params, opts) do
    Core.create_upload(
      uploader.bucket(),
      build_object_path(uploader, path_params),
      uploader.query(),
      create_params,
      opts
    )
  end

  defp build_object_path(uploader, path_params) do
    path_params = Map.merge(uploader.path() || %{}, path_params)

    case uploader.resource_name() do
      nil -> path_params
      resource_name -> Map.put(path_params, :resource_name, resource_name)
    end
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.Uploader

      @bucket opts[:bucket]

      @query opts[:query]

      @resource_name opts[:resource_name]

      @path opts[:path]

      def bucket, do: @bucket

      def query, do: @query

      def resource_name, do: @resource_name

      def path, do: @path

      def move_to_destination(dest_object, params_or_struct, opts) do
        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          opts
        )
      end

      def find_parts(params_or_struct, opts) do
        Uploader.find_parts(__MODULE__, params_or_struct, opts)
      end

      def sign_part(params_or_struct, part_number, opts) do
        Uploader.sign_part(__MODULE__, params_or_struct, part_number, opts)
      end

      def complete_multipart_upload(
            path_params,
            params_or_struct,
            update_params,
            parts,
            opts
          ) do
        Uploader.complete_multipart_upload(
          __MODULE__,
          path_params,
          params_or_struct,
          update_params,
          parts,
          opts
        )
      end

      def abort_multipart_upload(params_or_struct, update_params, opts) do
        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(path_params, create_params, opts) do
        Uploader.create_multipart_upload(
          __MODULE__,
          path_params,
          create_params,
          opts
        )
      end

      def complete_upload(path_params, params_or_struct, update_params, opts) do
        Uploader.complete_upload(
          __MODULE__,
          path_params,
          params_or_struct,
          update_params,
          opts
        )
      end

      def abort_upload(params_or_struct, update_params, opts) do
        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(path_params, create_params, opts) do
        Uploader.create_upload(
          __MODULE__,
          path_params,
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
