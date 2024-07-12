defmodule Uppy.Adapters.Scheduler.Oban.AdapterConfig do
  @moduledoc false

  @app Uppy.Config.app()

  @adapter Uppy.Adapters.Scheduler.Oban

  def adapter, do: Application.get_env(@app, @adapter) || [app: @app]

  def adapter_app, do: adapter()[:app] || @app

  def oban, do: Application.get_env(adapter_app(), @adapter) || []

  def oban_name, do: oban()[:name] || Uppy.Oban
end
