defmodule Uppy.Supervisor do
  @moduledoc false

  @default_name __MODULE__

  @default_opts [
    name: @default_name,
    http_adapter: Uppy.HTTP.Finch,
    scheduler_adapter: Uppy.Schedulers.ObanScheduler,
    storage_adapter: nil
  ]

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
    case opts[:http_adapter] do
      nil -> []
      mod -> [{mod, opts[:http] || []}]
    end
  end

  defp storage_child(opts) do
    case opts[:storage_adapter] do
      nil -> []
      mod -> [{mod, opts[:storage] || []}]
    end
  end

  defp scheduler_child(opts) do
    case opts[:scheduler_adapter] do
      nil -> []
      mod -> [{mod, opts[:scheduler] || []}]
    end
  end
end
