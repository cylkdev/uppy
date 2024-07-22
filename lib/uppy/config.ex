defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @spec app :: atom()
  def app, do: @app

  @doc false
  @spec error_message_adapter :: module()
  def error_message_adapter, do: Application.get_env(@app, :error_message_adapter) || ErrorMessage

  @doc false
  @spec json_adapter :: module()
  def json_adapter, do: Application.get_env(@app, :json_adapter) || Jason

  @doc false
  @spec http_adapter :: module()
  def http_adapter, do: Application.get_env(@app, :http_adapter) || Uppy.Adapters.HTTP.Finch

  @doc false
  @spec actions_adapter :: module() | nil
  def actions_adapter, do: Application.get_env(@app, :actions_adapter) || Uppy.Adapters.EctoShortsActions

  @doc false
  @spec scheduler_adapter :: module() | nil
  def scheduler_adapter, do: Application.get_env(@app, :scheduler_adapter) || Uppy.Adapters.Scheduler.Oban

  @doc false
  @spec storage_adapter :: module() | nil
  def storage_adapter, do: Application.get_env(@app, :storage_adapter) || Uppy.Adapters.Storage.S3

  @doc false
  @spec temporary_object_key_adapter :: module() | nil
  def temporary_object_key_adapter, do: Application.get_env(@app, :temporary_object_key_adapter) || Uppy.Adapters.TemporaryObjectKey

  @doc false
  @spec permanent_object_key_adapter :: module() | nil
  def permanent_object_key_adapter, do: Application.get_env(@app, :permanent_object_key_adapter) || Uppy.Adapters.PermanentObjectKey

  @doc false
  @spec oban :: module()
  def oban, do: Application.get_env(@app, Oban) || []
end
