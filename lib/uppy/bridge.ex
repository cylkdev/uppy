defmodule Uppy.Bridge do
  @moduledoc """
  Bridges provide a centralized place to manage configuration,
  adapters, and run-time behaviour for uploaders.
  """

  @default_name __MODULE__

  @default_opts [
    name: @default_name,
    http_adapter: Uppy.HTTP.Finch,
    scheduler_adapter: Uppy.Uploader.Schedulers.ObanScheduler
  ]

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    start_opts =
      opts
      |> Keyword.put(:name, supervisor_name(opts[:name]))
      |> Keyword.take([:name, :timeout])

    Supervisor.start_link(__MODULE__, opts, start_opts)
  end

  def child_spec(opts) do
    opts = Keyword.merge(@default_opts, opts)

    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def init(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    if opts[:bridge_enabled] === false do
      :ignore
    else
      init_opts =
        opts
        |> Keyword.take([:max_restarts, :max_seconds, :strategy])
        |> Keyword.put_new(:strategy, :one_for_one)

      opts[:name]
      |> supervisor_children(Keyword.delete(opts, :name))
      |> Supervisor.init(init_opts)
    end
  end

  @doc """
  Returns supervisor child spec list.
  """
  def supervisor_children(name, opts \\ []) do
    sup_name = supervisor_name(name)

    http_child(sup_name, opts) ++
      storage_child(sup_name, opts) ++
      scheduler_child(sup_name, opts)
  end

  @doc """
  Returns a list of information about the supervisor children.
  """
  def which_children(name) do
    name
    |> supervisor_name()
    |> Supervisor.which_children()
  end

  @doc """
  Returns `true` if the supervisor process is alive otherwise `false`.
  """
  def supervisor_alive?(name) do
    name
    |> where_is_supervisor()
    |> Process.alive?()
  end

  @doc """
  Returns the `pid` for the supervisor.
  """
  def where_is_supervisor(name) do
    name
    |> supervisor_name()
    |> Process.whereis()
  end

  defp supervisor_name(name) do
    :"#{Uppy.Utils.normalize_process_name(name)}_bridge_supervisor"
  end

  defp http_name(name), do: :"#{name}_http"

  defp storage_name(name), do: :"#{name}_storage"

  defp scheduler_name(name), do: :"#{name}_scheduler"

  defp http_child(name, opts) do
    if Keyword.has_key?(opts, :http_adapter) and Keyword.get(opts, :http_enabled, true) do
      adapter = opts[:http_adapter]

      if child_spec_function_exported?(adapter) do
        adapter_opts =
          opts
          |> Keyword.get(:http_options, [])
          |> Keyword.put(:name, http_name(name))

        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp storage_child(name, opts) do
    if Keyword.has_key?(opts, :storage_adapter) and Keyword.get(opts, :storage_enabled, true) do
      adapter = opts[:storage_adapter]

      if child_spec_function_exported?(adapter) do
        adapter_opts =
          opts
          |> Keyword.get(:storage_options, [])
          |> Keyword.put(:name, storage_name(name))

        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp scheduler_child(name, opts) do
    if Keyword.has_key?(opts, :scheduler_adapter) and Keyword.get(opts, :scheduler_enabled, true) do
      adapter = opts[:scheduler_adapter]

      adapter_opts =
        opts
        |> Keyword.get(:scheduler_options, [])
        |> Keyword.put(:name, scheduler_name(name))

      if child_spec_function_exported?(adapter) do
        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp child_spec_function_exported?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :child_spec, 1)
  end

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

      alias Uppy.{Bridge, Uploader}

      @name name

      @repo repo

      @required_supervisor_opts supervisor_opts

      @required_opts options

      unquote(Uppy.Bridge.DBActionTemplate.quoted_ast(opts))

      def options, do: @required_opts

      def start_link(opts \\ []) do
        opts
        |> Keyword.merge(@required_supervisor_opts)
        |> Bridge.start_link()
      end

      def child_spec(opts \\ []) do
        opts
        |> Keyword.merge(@required_supervisor_opts)
        |> Bridge.child_spec()
      end

      @impl true
      def init(opts \\ []) do
        opts
        |> Keyword.merge(@required_supervisor_opts)
        |> Bridge.init()
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
          builder_params,
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
          builder_params,
          Keyword.merge(opts, @required_opts)
        )
      end

      def complete_upload(uploader, params_or_struct, update_params, builder_params, opts \\ []) do
        Uploader.complete_upload(
          uploader,
          params_or_struct,
          update_params,
          builder_params,
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
          builder_params,
          Keyword.merge(opts, @required_opts)
        )
      end
    end
  end
end
