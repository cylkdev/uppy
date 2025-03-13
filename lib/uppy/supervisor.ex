defmodule Uppy.Supervisor do
  @moduledoc false
  use Supervisor

  @default_name __MODULE__

  @default_opts [
    name: @default_name
  ]

  def start_link(name \\ @default_name, bridges, opts \\ []) do
    opts =
      @default_opts
      |> Keyword.merge(opts)
      |> Keyword.put(:name, name)

    sup_opts = Keyword.take(opts, [:name, :timeout])

    init_opts = Keyword.put(opts, :bridges, bridges)

    Supervisor.start_link(__MODULE__, init_opts, sup_opts)
  end

  def child_spec(opts) do
    opts = Keyword.merge(@default_opts, opts)

    name = opts[:name] || @default_name

    bridges = opts[:bridges] || []

    opts = Keyword.drop(opts, [:name, :bridges])

    %{
      id: name,
      start: {__MODULE__, :start_link, [name, bridges, opts]}
    }
  end

  def init(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    init_opts =
      opts
      |> Keyword.take([:max_restarts, :max_seconds, :strategy])
      |> Keyword.put_new(:strategy, :one_for_one)

    opts
    |> Keyword.get(:bridges, [])
    |> Enum.map(&normalize_sup_child_spec/1)
    |> Enum.reject(&process_alive?/1)
    |> IO.inspect()
    |> Supervisor.init(init_opts)
  end

  defp process_alive?({bridge, opts}) do
    opts
    |> Keyword.get(:name, bridge)
    |> Uppy.Utils.process_alive?()
  end

  defp normalize_sup_child_spec({mod, opts}), do: {mod, opts}
  defp normalize_sup_child_spec(mod), do: {mod, []}
end
