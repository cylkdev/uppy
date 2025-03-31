defmodule Uppy.Supervisor do
  @moduledoc false

  @default_name __MODULE__

  @default_opts [
    name: @default_name,
    http_enabled: true,
    http_adapter: Uppy.HTTP.Finch,
    scheduler_enabled: true,
    scheduler_adapter: Uppy.Schedulers.ObanScheduler,
    storage_enabled: true,
    storage_adapter: Uppy.Storages.S3
  ]

  def start_link(opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    sup_opts = Keyword.take(opts, [:name, :timeout])

    Supervisor.start_link(__MODULE__, opts, sup_opts)
  end

  def child_spec(opts) do
    opts = Keyword.merge(default_opts(), opts)

    %{
      id: opts[:name],
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def init(opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    init_opts =
      opts
      |> Keyword.get(:init, [])
      |> Keyword.take([:max_restarts, :max_seconds, :strategy])
      |> Keyword.put_new(:strategy, :one_for_one)

    children =
      http_child(opts) ++
        storage_child(opts) ++
        scheduler_child(opts)

    Supervisor.init(children, init_opts)
  end

  defp http_child(opts) do
    if Keyword.has_key?(opts, :http_adapter) and Keyword.get(opts, :http_enabled, true) do
      adapter = opts[:http_adapter]
      adapter_opts = opts[:http] || []

      if child_spec_exported?(adapter) do
        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp storage_child(opts) do
    if Keyword.has_key?(opts, :storage_adapter) and Keyword.get(opts, :storage_enabled, true) do
      adapter = opts[:storage_adapter]
      adapter_opts = opts[:storage] || []

      if child_spec_exported?(adapter) do
        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp scheduler_child(opts) do
    if Keyword.has_key?(opts, :scheduler_adapter) and Keyword.get(opts, :scheduler_enabled, true) do
      adapter = opts[:scheduler_adapter]
      adapter_opts = opts[:scheduler] || []

      if child_spec_exported?(adapter) do
        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp child_spec_exported?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :child_spec, 1)
  end

  defp default_opts do
    Keyword.merge(
      @default_opts,
      Uppy.Utils.drop_nil_values(
        http_adapter: Uppy.Config.http_adapter(),
        scheduler_adapter: Uppy.Config.scheduler_adapter(),
        storage_adapter: Uppy.Config.storage_adapter()
      )
    )
  end
end
