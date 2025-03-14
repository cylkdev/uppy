defmodule Uppy.Uploader do
  @moduledoc false

  alias Uppy.Core

  def __uploader__(uploader), do: uploader.__uploader__()

  def bucket(uploader), do: uploader.bucket()

  def query(uploader), do: uploader.query()

  def resource_name(uploader), do: uploader.resource_name()

  def path_params(uploader), do: uploader.path_params()

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
        params_or_struct,
        update_params,
        parts,
        path_params,
        opts
      ) do
    path_params = uploader |> path_params() |> Map.merge(path_params)

    Core.complete_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      parts,
      path_params,
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

  def create_multipart_upload(uploader, filename, create_params, path_params, opts) do
    path_params = uploader |> path_params() |> Map.merge(path_params)

    Core.create_multipart_upload(
      uploader.bucket(),
      uploader.query(),
      filename,
      create_params,
      path_params,
      opts
    )
  end

  def complete_upload(uploader, params_or_struct, update_params, path_params, opts) do
    path_params = uploader |> path_params() |> Map.merge(path_params)

    Core.complete_upload(
      uploader.bucket(),
      uploader.query(),
      params_or_struct,
      update_params,
      path_params,
      opts
    )
  end

  def abort_upload(uploader, filename, params, opts) do
    Core.abort_upload(uploader.bucket(), uploader.query(), filename, params, opts)
  end

  def create_upload(uploader, filename, create_params, path_params, opts) do
    path_params = uploader |> path_params() |> Map.merge(path_params)

    Core.create_upload(
      uploader.bucket(),
      uploader.query(),
      filename,
      create_params,
      path_params,
      opts
    )
  end

  defp put_uploader_path_params(path_params, uploader) do
    case uploader.path_params() do
      nil -> path_params
      params -> Map.merge(params, path_params)
    end
  end

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)

      alias Uppy.Uploader

      @bucket opts[:bucket]

      @query opts[:query]

      @resource_name opts[:resource_name]

      @path_params (if is_nil(@resource_name) do
                      opts[:path_params] || %{}
                    else
                      opts
                      |> Keyword.get(:path_params, %{})
                      |> Map.put(:resource_name, @resource_name)
                    end)

      @bridge_adapter opts[:bridge_adapter]

      @__uploader__ %{
        bucket: @bucket,
        query: @query,
        resource_name: @resource_name,
        path_params: @path_params,
        bridge_adapter: @bridge_adapter
      }

      def __uploader__, do: @__uploader__

      def bucket, do: @bucket

      def query, do: @query

      def resource_name, do: @resource_name

      def path_params, do: @path_params

      def move_to_destination(dest_object, params_or_struct, opts \\ []) do
        Uploader.move_to_destination(
          __MODULE__,
          dest_object,
          params_or_struct,
          opts
        )
      end

      def find_parts(params_or_struct, opts \\ []) do
        Uploader.find_parts(__MODULE__, params_or_struct, opts)
      end

      def sign_part(params_or_struct, part_number, opts \\ []) do
        Uploader.sign_part(__MODULE__, params_or_struct, part_number, opts)
      end

      def complete_multipart_upload(
            params_or_struct,
            update_params,
            parts,
            path_params,
            opts \\ []
          ) do
        IO.inspect(binding(), label: "caller params")

        Uploader.complete_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          parts,
          path_params,
          opts
        )
      end

      def abort_multipart_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_multipart_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_multipart_upload(filename, create_params, path_params, opts \\ []) do
        Uploader.create_multipart_upload(
          __MODULE__,
          filename,
          create_params,
          path_params,
          opts
        )
      end

      def complete_upload(params_or_struct, update_params, path_params, opts \\ []) do
        Uploader.complete_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          path_params,
          opts
        )
      end

      def abort_upload(params_or_struct, update_params, opts \\ []) do
        Uploader.abort_upload(
          __MODULE__,
          params_or_struct,
          update_params,
          opts
        )
      end

      def create_upload(filename, create_params, path_params, opts \\ []) do
        Uploader.create_upload(
          __MODULE__,
          filename,
          create_params,
          path_params,
          opts
        )
      end

      defoverridable abort_upload: 3,
                     create_upload: 4,
                     complete_upload: 4,
                     abort_multipart_upload: 3,
                     create_multipart_upload: 4,
                     complete_multipart_upload: 4,
                     sign_part: 3,
                     find_parts: 2,
                     move_to_destination: 3
    end
  end
end
