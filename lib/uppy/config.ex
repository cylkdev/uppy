defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  def from_app_env(module, default \\ []) do
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

  # @spec http_adapter :: module() | nil
  # def http_adapter do
  #   Application.get_env(@app, :http_adapter) || Uppy.HTTP.Finch
  # end

  # @spec db_action_adapter :: module() | nil
  # def db_action_adapter do
  #   Application.get_env(@app, :db_action_adapter) || Uppy.DBActions.SimpleRepo
  # end

  # @spec scheduler_adapter :: module()
  # def scheduler_adapter do
  #   Application.get_env(@app, :scheduler_adapter) || Uppy.Uploader.Engines.ObanScheduler
  # end

  # @spec storage_adapter :: module()
  # def storage_adapter, do: Application.get_env(@app, :storage_adapter) || Uppy.Storages.S3
end
