defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @doc false
  @spec app :: :uppy
  def app, do: @app

  @doc false
  @spec repo :: module() | nil
  def repo do
    Application.get_env(@app, :repo) || Uppy.Repo
  end

  @doc false
  @spec error_adapter :: module() | nil
  def error_adapter do
    Application.get_env(@app, :error_adapter) || ErrorMessage
  end

  @doc false
  @spec json_adapter :: module() | nil
  def json_adapter do
    Application.get_env(@app, :json_adapter) || Jason
  end

  @doc false
  @spec http_adapter :: module() | nil
  def http_adapter do
    Application.get_env(@app, :http_adapter)
  end

  @doc false
  @spec db_action_adapter :: module() | nil
  def db_action_adapter do
    Application.get_env(@app, :db_action_adapter)
  end

  @doc false
  @spec scheduler_adapter :: module() | nil
  def scheduler_adapter do
    Application.get_env(@app, :scheduler_adapter)
  end

  @doc false
  @spec storage_adapter :: module() | nil
  def storage_adapter do
    Application.get_env(@app, :storage_adapter)
  end
end
