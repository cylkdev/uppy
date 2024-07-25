defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @doc false
  @spec app :: :uppy
  def app, do: @app

  @doc false
  @spec error_message_adapter :: module() | nil
  def error_message_adapter do
    Application.get_env(@app, :error_message_adapter)
  end

  @doc false
  @spec json_adapter :: module() | nil
  def json_adapter do
    Application.get_env(@app, :json_adapter)
  end

  @doc false
  @spec http_adapter :: module() | nil
  def http_adapter do
    Application.get_env(@app, :http_adapter)
  end

  @doc false
  @spec actions_adapter :: module() | nil
  def actions_adapter do
    Application.get_env(@app, :actions_adapter)
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

  @doc false
  @spec temporary_object_key_adapter :: module() | nil
  def temporary_object_key_adapter do
    Application.get_env(@app, :temporary_object_key_adapter)
  end

  @doc false
  @spec permanent_object_key_adapter :: module() | nil
  def permanent_object_key_adapter do
    Application.get_env(@app, :permanent_object_key_adapter)
  end
end
