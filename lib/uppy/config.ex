defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  def app, do: @app

  def from_app_env(module, default \\ nil) do
    Application.get_env(@app, module) || default
  end

  @spec bucket :: binary() | nil
  def bucket do
    Application.get_env(@app, :bucket)
  end

  @spec error_adapter :: module() | nil
  def error_adapter do
    Application.get_env(@app, :error_adapter) || ErrorMessage
  end

  @spec json_adapter :: module() | nil
  def json_adapter do
    Application.get_env(@app, :json_adapter) || Jason
  end

  @spec db_action_adapter :: module() | nil
  def db_action_adapter do
    Application.get_env(@app, :db_action_adapter) || Uppy.DBActions.SimpleRepo
  end
end
