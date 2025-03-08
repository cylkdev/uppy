defmodule Uppy.Upload do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      use Supervisor

      alias Uppy.{Upload, Uploader}

      @name __MODULE__

      @adapter_fields ~w(http_adapter scheduler_adapter storage_adapter)a

      @adapter_opts_fields ~w(http_options scheduler_options storage_options)a

      @supervisor_opts opts
                       |> Keyword.take(@adapter_fields ++ @adapter_opts_fields)
                       |> Keyword.put(:name, @name)

      @required_opts Keyword.merge(opts[:options] || [], Keyword.take(opts, @adapter_fields))

      @resource_name opts[:resource_name]

      Uppy.Upload.DBActionTemplate.quoted_ast(opts)

      def resource_name, do: @resource_name

      def options, do: @required_opts

      def start_link(opts \\ []) do
        opts
        |> Keyword.merge(@supervisor_opts)
        |> Upload.Supervisor.start_link()
      end

      def child_spec(opts \\ []) do
        opts
        |> Keyword.merge(@supervisor_opts)
        |> Upload.Supervisor.child_spec()
      end

      @impl true
      def init(opts \\ []) do
        opts
        |> Keyword.merge(@supervisor_opts)
        |> Upload.Supervisor.init()
      end

      def move_to_destination(uploader, dest_object, params_or_struct, opts \\ []) do
        Uploader.move_to_destination(
          uploader,
          dest_object,
          params_or_struct,
          Keyword.merge(opts, @required_opts)
        )
      end

      def find_parts(uploader, params_or_struct, opts \\ []) do
        Uploader.find_parts(
          uploader,
          params_or_struct,
          Keyword.merge(opts, @required_opts)
        )
      end

      def sign_part(uploader, params_or_struct, part_number, opts \\ []) do
        Uploader.sign_part(
          uploader,
          params_or_struct,
          part_number,
          Keyword.merge(opts, @required_opts)
        )
      end

      def complete_multipart_upload(
            uploader,
            params_or_struct,
            update_params,
            parts,
            builder_params,
            opts
          ) do
        Uploader.complete_multipart_upload(
          uploader,
          params_or_struct,
          update_params,
          parts,
          maybe_put_resource_name(builder_params, @resource_name),
          Keyword.merge(opts, @required_opts)
        )
      end

      def abort_multipart_upload(uploader, params_or_struct, update_params, opts \\ []) do
        Uploader.abort_multipart_upload(
          uploader,
          params_or_struct,
          update_params,
          Keyword.merge(opts, @required_opts)
        )
      end

      def create_multipart_upload(uploader, filename, params, builder_params, opts \\ []) do
        Uploader.create_multipart_upload(
          uploader,
          filename,
          params,
          maybe_put_resource_name(builder_params, @resource_name),
          Keyword.merge(opts, @required_opts)
        )
      end

      def complete_upload(uploader, params_or_struct, update_params, builder_params, opts \\ []) do
        Uploader.complete_upload(
          uploader,
          params_or_struct,
          update_params,
          maybe_put_resource_name(builder_params, @resource_name),
          Keyword.merge(opts, @required_opts)
        )
      end

      def abort_upload(uploader, params_or_struct, update_params, opts \\ []) do
        Uploader.abort_upload(
          uploader,
          params_or_struct,
          update_params,
          Keyword.merge(opts, @required_opts)
        )
      end

      def create_upload(uploader, filename, params, builder_params, opts \\ []) do
        Uploader.create_upload(
          uploader,
          filename,
          params,
          maybe_put_resource_name(builder_params, @resource_name),
          Keyword.merge(opts, @required_opts)
        )
      end

      defp maybe_put_resource_name(params, nil), do: params
      defp maybe_put_resource_name(params, val), do: Map.put(params, :resource_name, val)
    end
  end
end
