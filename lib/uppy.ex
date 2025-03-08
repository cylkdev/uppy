defmodule Uppy do
  @moduledoc false
  use Supervisor

  alias Uppy.Bridge

  @default_name __MODULE__

  @default_options [
    name: @default_name
  ]

  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    Supervisor.start_link(__MODULE__, opts, Keyword.take(opts, [:name, :timeout]))
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

    init_opts =
      opts
      |> Keyword.take([:max_restarts, :max_seconds, :strategy])
      |> Keyword.put_new(:strategy, :one_for_one)

    opts
    |> Keyword.get(:bridges, [])
    |> Enum.map(&normalize_sup_child_spec/1)
    |> Enum.reject(&bridge_already_started?/1)
    |> Supervisor.init(init_opts)
  end

  defp bridge_already_started?({bridge, _opts}) do
    Bridge.supervisor_alive?(bridge)
  end

  defp normalize_sup_child_spec({mod, opts}), do: {mod, opts}
  defp normalize_sup_child_spec(mod), do: {mod, []}
end
