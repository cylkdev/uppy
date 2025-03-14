defmodule Uppy.Bridge do
  @moduledoc """
  Bridges provide a centralized place to manage configuration,
  adapters, and run-time behaviour for Uploaders.

  ## Getting Started

  Application.ensure_all_started(:postgrex)
  Application.ensure_all_started(:ecto)
  Application.ensure_all_started(:oban)
  Uppy.Support.Repo.start_link()

  ```elixir
  Uppy.Bridge.start_link(scheduler: [repo: Uppy.Support.Repo])
  ```

  ```elixir
  defmodule MyApp.Bridge do
    use Uppy.Bridge,
      http_adapter: Uppy.HTTP.Finch,
      scheduler_adapter: Uppy.Schedulers.Oban,
      storage_adapter: Uppy.Storages.S3,
      options: [scheduler: [repo: Uppy.Support.Repo]]
  end
  ```

  ```elixir
  MyApp.Bridge.start_link(scheduler: [repo: Uppy.Support.Repo])
  ```
  """

  @default_http_adapter Uppy.HTTP.Finch

  @default_scheduler_adapter Uppy.Schedulers.Oban

  @default_storage_adapter Uppy.Storages.S3

  @default_opts [
    name: __MODULE__,
    http_enabled: true,
    http_adapter: @default_http_adapter,
    scheduler_enabled: true,
    scheduler_adapter: @default_scheduler_adapter,
    storage_enabled: true,
    storage_adapter: @default_storage_adapter
  ]

  def http_adapter(bridge), do: bridge.http_adapter()

  @doc """
  Returns a keyword-list of options for the `bridge` http adapter.
  """
  def http(bridge), do: bridge.http()

  @doc """
  Returns the `bridge` scheduler adapter module.
  """
  def scheduler_adapter(bridge), do: bridge.scheduler_adapter()

  @doc """
  Returns a keyword-list of options for the `bridge` scheduler adapter.
  """
  def scheduler(bridge), do: bridge.scheduler()

  @doc """
  Returns the `bridge` storage adapter module.
  """
  def storage_adapter(bridge), do: bridge.storage_adapter()

  @doc """
  Returns a keyword-list of options for the `bridge` storage adapter.
  """
  def storage(bridge), do: bridge.storage()

  def build_options(bridge) do
    Uppy.Utils.drop_nil_values(
      http_adapter: bridge.http_adapter(),
      http: bridge.http(),
      scheduler_adapter: bridge.scheduler_adapter(),
      scheduler: bridge.scheduler(),
      storage_adapter: bridge.storage_adapter(),
      storage: bridge.storage()
    )
  end

  def build_supervisor_options(opts, bridge) do
    bridge
    |> build_options()
    |> Keyword.merge(opts)
    |> Keyword.put(:name, bridge)
  end

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    sup_opts = Keyword.take(opts, [:name, :timeout])

    Supervisor.start_link(__MODULE__, opts, sup_opts)
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

    init_opts =
      opts
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
      adapter = opts[:http_adapter] || @default_http_adapter

      adapter_opts = opts[:http] || []

      if child_spec_exported?(adapter) and not process_alive?(adapter, adapter_opts) do
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
      adapter = opts[:storage_adapter] || @default_storage_adapter

      adapter_opts = opts[:storage] || []

      if child_spec_exported?(adapter) and not process_alive?(adapter, adapter_opts) do
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
      adapter = opts[:scheduler_adapter] || @default_scheduler_adapter

      adapter_opts = opts[:scheduler] || []

      if child_spec_exported?(adapter) and not process_alive?(adapter, adapter_opts) do
        [{adapter, adapter_opts}]
      else
        []
      end
    else
      []
    end
  end

  defp process_alive?(adapter, adapter_opts) do
    name = adapter_opts[:name] || adapter

    if function_exported?(adapter, :alive?, 1) do
      adapter.alive?(name)
    else
      Uppy.Utils.process_alive?(name)
    end
  end

  defp child_spec_exported?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :child_spec, 1)
  end

  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      alias Uppy.Bridge

      # http

      @http_adapter opts[:http_adapter] || Uppy.HTTP.Finch

      @http opts[:http]

      # scheduler

      @scheduler_adapter opts[:scheduler_adapter] || Uppy.Schedulers.Oban

      @scheduler opts[:scheduler]

      # storage

      @storage_adapter opts[:storage_adapter] || Uppy.Storages.S3

      @storage opts[:storage]

      def http_adapter, do: @http_adapter

      def http, do: @http

      def scheduler_adapter, do: @scheduler_adapter

      def scheduler, do: @scheduler

      def storage_adapter, do: @storage_adapter

      def storage, do: @storage

      def start_link(opts \\ []) do
        opts
        |> Bridge.build_supervisor_options(__MODULE__)
        |> Bridge.start_link()
      end

      def child_spec(opts) do
        opts
        |> Bridge.build_supervisor_options(__MODULE__)
        |> Bridge.child_spec()
      end
    end
  end
end
