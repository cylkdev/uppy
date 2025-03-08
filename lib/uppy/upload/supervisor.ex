defmodule Uppy.Upload.Supervisor do
  @moduledoc false

  @default_name __MODULE__

  @default_options [
    name: @default_name,
    http_adapter: Uppy.HTTP.Finch,
    scheduler_adapter: Uppy.Uploader.Schedulers.ObanScheduler
  ]

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    start_opts =
      opts
      |> Keyword.put(:name, supervisor_name(opts[:name]))
      |> Keyword.take([:name, :timeout])

    Supervisor.start_link(__MODULE__, opts, start_opts)
  end

  def child_spec(opts) do
    opts = Keyword.merge(@default_options, opts)

    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def init(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    sup_name = supervisor_name(opts[:name])

    if opts[:enabled] === false do
      :ignore
    else
      init_opts =
        opts
        |> Keyword.take([:max_restarts, :max_seconds, :strategy])
        |> Keyword.put_new(:strategy, :one_for_one)

      sup_name
      |> supervisor_children(opts)
      |> Supervisor.init(init_opts)
    end
  end

  def supervisor_alive?(name) do
    name
    |> where_is_supervisor()
    |> Process.alive?()
  end

  def where_is_supervisor(name) do
    name
    |> supervisor_name()
    |> Process.whereis()
  end

  def supervisor_name(name) do
    name = to_string(name)

    name =
      if String.contains?(name, ".") do
        name
        |> String.replace("Elixir.", "")
        |> String.split(".", trim: true)
        |> List.last()
        |> Macro.underscore()
        |> String.trim_trailing("_supervisor")
      else
        String.trim_trailing(name, "_supervisor")
      end

    :"#{name}_supervisor"
  end

  def supervisor_children(name, opts) do
    http_child(name, opts) ++
      storage_child(name, opts) ++
      scheduler_child(name, opts)
  end

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

  defp http_name(name), do: :"#{name}_http"

  defp storage_name(name), do: :"#{name}_storage"

  defp scheduler_name(name), do: :"#{name}_scheduler"

  defp child_spec_function_exported?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :child_spec, 1)
  end
end
