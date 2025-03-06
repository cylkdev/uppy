defmodule Uppy do
  @moduledoc false
  use Supervisor

  @default_name Uppy

  @default_opts [
    name: @default_name
  ]

  @doc false
  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    init_opts = Keyword.take(opts, [:http, :scheduler])

    supervisor_opts =
      opts
      |> Keyword.put_new(:name, @default_name)
      |> Keyword.drop([:http, :scheduler])

    Supervisor.start_link(__MODULE__, init_opts, supervisor_opts)
  end

  def child_spec(opts) do
    opts = Keyword.put_new(opts, :name, @default_name)

    %{
      id: opts[:name],
      start: {Uppy, :start_link, [opts]}
    }
  end

  @impl true
  @doc false
  def init(init_opts \\ []) do
    init_opts
    |> children()
    |> Supervisor.init(strategy: :one_for_one)
  end

  @doc false
  def children(init_opts \\ []) do
    [
      {Uppy.HTTP.Finch, init_opts[:http][:options] || []},
      {Uppy.Schedulers.ObanScheduler, init_opts[:scheduler][:options] || []}
    ]
  end
end
