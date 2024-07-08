defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @spec app :: atom()
  def app, do: @app

  @doc false
  @spec error_message_adapter :: module()
  def error_message_adapter do
    Application.get_env(@app, :error_message_adapter) || ErrorMessage
  end

  @doc false
  @spec actions_adapter :: module()
  def actions_adapter do
    Application.get_env(@app, :actions_adapter) || Uppy.Adapters.Actions
  end

  @doc false
  @spec pipeline :: list()
  def pipeline do
    Application.get_env(@app, :pipeline) || []
  end

  if Code.ensure_loaded?(Oban) do
    @spec oban :: Keyword.t()
    def oban, do: Application.get_env(@app, Oban, [])
  end
end
