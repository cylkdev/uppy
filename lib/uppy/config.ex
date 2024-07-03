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

  @doc false
  @spec web_safe_filename_enabled :: boolean()
  def web_safe_filename_enabled do
    Application.get_env(@app, :web_safe_filename_enabled) || true
  end
end
