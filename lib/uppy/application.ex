defmodule Uppy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Uppy.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def children do
    http_children()
  end

  def http_children do
    if Uppy.Config.http_adapter() in [Uppy.HTTP.Finch] do
      [Uppy.HTTP.Finch]
    else
      []
    end
  end
end
