defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

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
    Application.get_env(@app, :db_action_adapter) || Uppy.CommonRepoAction
  end

  @spec enable_scheduler :: true | false
  def enable_scheduler do
    Application.get_env(@app, :enable_scheduler) || true
  end

  @spec scheduler_adapter :: module() | nil
  def scheduler_adapter do
    Application.get_env(@app, :scheduler_adapter) || Uppy.Schedulers.ObanScheduler
  end

  @spec storage_adapter :: module() | nil
  def storage_adapter, do: Application.get_env(@app, :storage_adapter) || Uppy.Storages.S3

  @spec repo :: atom() | nil
  def repo, do: Application.get_env(@app, :repo) || Uppy.Repo

  @spec oban_name :: atom() | nil
  def oban_name, do: Application.get_env(@app, :oban_name) || :uppy_oban

  @spec pipeline_module :: atom() | nil
  def pipeline_module, do: Application.get_env(@app, :pipeline_module)
end
