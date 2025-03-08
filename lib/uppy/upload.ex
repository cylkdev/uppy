defmodule Uppy.Upload do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      name = __MODULE__

      adapter_fields = ~w(http_adapter scheduler_adapter storage_adapter)a

      adapter_opts_fields = ~w(http_options scheduler_options storage_options)a

      supervisor_opts =
        opts
        |> Keyword.take(adapter_fields ++ adapter_opts_fields)
        |> Keyword.put(:name, name)

      repo = opts[:repo]

      options =
        opts
        |> Keyword.get(:options, [])
        |> Keyword.take(adapter_fields)
        |> then(fn opts -> if is_nil(repo), do: opts, else: Keyword.put(opts, :repo, repo) end)

      # ---

      use Supervisor

      alias Uppy.{Upload, Uploader}

      @name name

      @repo repo

      @supervisor_opts supervisor_opts

      @options options

      unquote(Uppy.Upload.DBActionTemplate.quoted_ast(opts))

      def options, do: @options

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
          Keyword.merge(opts, @options)
        )
      end

      def find_parts(uploader, params_or_struct, opts \\ []) do
        Uploader.find_parts(
          uploader,
          params_or_struct,
          Keyword.merge(opts, @options)
        )
      end

      def sign_part(uploader, params_or_struct, part_number, opts \\ []) do
        Uploader.sign_part(
          uploader,
          params_or_struct,
          part_number,
          Keyword.merge(opts, @options)
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
          builder_params,
          Keyword.merge(opts, @options)
        )
      end

      def abort_multipart_upload(uploader, params_or_struct, update_params, opts \\ []) do
        Uploader.abort_multipart_upload(
          uploader,
          params_or_struct,
          update_params,
          Keyword.merge(opts, @options)
        )
      end

      def create_multipart_upload(uploader, filename, params, builder_params, opts \\ []) do
        Uploader.create_multipart_upload(
          uploader,
          filename,
          params,
          builder_params,
          Keyword.merge(opts, @options)
        )
      end

      def complete_upload(uploader, params_or_struct, update_params, builder_params, opts \\ []) do
        Uploader.complete_upload(
          uploader,
          params_or_struct,
          update_params,
          builder_params,
          Keyword.merge(opts, @options)
        )
      end

      def abort_upload(uploader, params_or_struct, update_params, opts \\ []) do
        Uploader.abort_upload(
          uploader,
          params_or_struct,
          update_params,
          Keyword.merge(opts, @options)
        )
      end

      def create_upload(uploader, filename, params, builder_params, opts \\ []) do
        Uploader.create_upload(
          uploader,
          filename,
          params,
          builder_params,
          Keyword.merge(opts, @options)
        )
      end
    end
  end
end
