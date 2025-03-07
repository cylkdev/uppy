defmodule Uppy do
  @moduledoc false
  use Supervisor

  @logger_prefix "Uppy"

  @default_name Uppy

  @default_options [name: @default_name]

  @doc false
  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    Supervisor.start_link(__MODULE__, opts, Keyword.take(opts, [:name, :timeout]))
  end

  def child_spec(opts) do
    opts = Keyword.put_new(opts, :name, @default_name)

    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl true
  @doc false
  def init(opts \\ []) do
    init_opts =
      opts
      |> Keyword.take([:strategy, :max_restarts, :max_seconds])
      |> Keyword.put_new(:strategy, :one_for_one)

    opts
    |> Keyword.get(:uploaders, [])
    |> children_from_uploaders(opts)
    |> Supervisor.init(init_opts)
  end

  @adapter_fields [
    :http_adapter,
    :job_engine_adapter,
    :storage_adapter
  ]

  defp children_from_uploaders(modules, opts) do
    if Keyword.get(opts, :enabled, true) do
      children =
        Enum.flat_map(modules, fn mod ->
          @adapter_fields
          |> Enum.map(&normalize_children(&1, mod))
          |> Enum.uniq()
          |> Enum.map(&sup_child_spec(&1, opts))
        end)

      Uppy.Utils.Logger.debug(
        @logger_prefix,
        "starting children:\n\n#{inspect(children, pretty: true)}"
      )

      children
    else
      Uppy.Utils.Logger.debug(@logger_prefix, "startup disabled.")

      []
    end
  end

  defp sup_child_spec({:http_adapter, adapter}, opts) do
    if opts[:http_adapter] === false do
      []
    else
      [{adapter, adapter_opts(adapter, :http, opts)}]
    end
  end

  defp sup_child_spec({:job_engine, adapter}, opts) do
    if opts[:job_engine] === false do
      []
    else
      [{adapter, adapter_opts(adapter, :job_engine, opts)}]
    end
  end

  defp sup_child_spec({:storage, adapter}, opts) do
    if opts[:storage] === false do
      []
    else
      [{adapter, adapter_opts(adapter, :storage, opts)}]
    end
  end

  defp adapter_opts(adapter, key, opts) do
    if function_exported?(adapter, :supervisor_child_opts, 1) do
      adapter.supervisor_child_opts(opts)
    else
      case Keyword.get(opts, key) do
        nil -> Uppy.Config.from_app_env(adapter)
        adapter_opts -> adapter_opts
      end
    end
  end

  defp normalize_children(:http_adapter, mod) do
    {:http_adapter, mod.http_adapter()}
  end

  defp normalize_children(:job_engine_adapter, mod) do
    {:job_engine_adapter, mod.job_engine_adapter()}
  end

  defp normalize_children(:storage_adapter, mod) do
    {:storage_adapter, mod.storage_adapter()}
  end
end
