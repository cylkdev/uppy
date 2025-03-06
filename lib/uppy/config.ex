defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  def app, do: @app

  @spec error_adapter :: module() | nil
  def error_adapter do
    Application.get_env(@app, :error_adapter) || ErrorMessage
  end

  @spec json_adapter :: module() | nil
  def json_adapter do
    Application.get_env(@app, :json_adapter) || Jason
  end

  @spec http_adapter :: module() | nil
  def http_adapter do
    Application.get_env(@app, :http_adapter) || Uppy.HTTP.Finch
  end

  @spec db_action_adapter :: module() | nil
  def db_action_adapter do
    Application.get_env(@app, :db_action_adapter) || Uppy.CommonRepoActions
  end

  @spec scheduler_enabled :: true | false
  def scheduler_enabled do
    Application.get_env(@app, :scheduler_enabled) || true
  end

  @spec scheduler_adapter :: module()
  def scheduler_adapter do
    Application.get_env(@app, :scheduler_adapter) || Uppy.Schedulers.ObanScheduler
  end

  @spec storage_adapter :: module()
  def storage_adapter, do: Application.get_env(@app, :storage_adapter) || Uppy.Storages.S3

  @spec pipeline_module :: atom() | nil
  def pipeline_module, do: Application.get_env(@app, :pipeline_module)
end
