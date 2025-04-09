defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  def get_app_env(key, default \\ nil), do: Application.get_env(@app, key) || default

  @spec error_adapter :: module()
  def error_adapter do
    Application.get_env(@app, :error_adapter) || ErrorMessage
  end

  @spec json_adapter :: module()
  def json_adapter do
    Application.get_env(@app, :json_adapter) || Jason
  end

  @spec db_action_adapter :: module()
  def db_action_adapter do
    Application.get_env(@app, :db_action_adapter) || Uppy.DBActions.SimpleRepo
  end

  @spec http_adapter :: module()
  def http_adapter do
    Application.get_env(@app, :http_adapter) || Uppy.HTTP.Finch
  end

  @spec storage_adapter :: module()
  def storage_adapter do
    Application.get_env(@app, :storage_adapter) || Uppy.Storages.S3
  end

  @spec storage :: keyword() | nil
  def storage do
    Application.get_env(@app, :storage)
  end

  @spec scheduler_adapter :: module()
  def scheduler_adapter do
    Application.get_env(@app, :scheduler_adapter) || Uppy.Schedulers.ObanScheduler
  end
end
