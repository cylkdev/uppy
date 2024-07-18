defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @spec app :: atom()
  def app, do: @app

  @doc false
  @spec atomize_keys? :: module()
  def atomize_keys?, do: Application.get_env(@app, :atomize_keys?) || true

  @doc false
  @spec error_message_adapter :: module()
  def error_message_adapter, do: Application.get_env(@app, :error_message_adapter) || ErrorMessage

  @doc false
  @spec json_adapter :: module()
  def json_adapter, do: Application.get_env(@app, :json_adapter) || Jason

  @doc false
  @spec http_adapter :: module()
  def http_adapter, do: Application.get_env(@app, :http_adapter) || Uppy.Adapters.HTTP.Finch

  # context configuration

  @doc false
  @spec bucket :: String.t()
  def bucket, do: Application.get_env(@app, :bucket) || "<UPPY_BUCKET>"

  @doc false
  @spec resource_name :: String.t()
  def resource_name, do: Application.get_env(@app, :resource_name)

  @doc false
  @spec storage_adapter :: module()
  def storage_adapter, do: Application.get_env(@app, :storage_adapter) || Uppy.Adapters.Storage.S3

  @doc false
  @spec action_adapter :: module()
  def action_adapter, do: Application.get_env(@app, :action_adapter) || Uppy.Adapters.Action

  @doc false
  @spec temporary_scope_adapter :: module()
  def temporary_scope_adapter, do: Application.get_env(@app, :temporary_scope_adapter) || Uppy.Adapters.TemporaryScope

  @doc false
  @spec permanent_scope_adapter :: module()
  def permanent_scope_adapter, do: Application.get_env(@app, :permanent_scope_adapter) || Uppy.Adapters.PermanentScope

  # @doc false
  # @spec thumbor_adapter :: module()
  # def thumbor_adapter do
  #   Application.get_env(@app, :thumbor_adapter) || Uppy.Adapters.Thumbor
  # end

  # @doc false
  # @spec thumbor :: Keyword.t()
  # def thumbor do
  #   Application.get_env(@app, :thumbor) || []
  # end

  # def oban_adapter(adapter) do
  #   Application.get_env(@app, adapter) || [app: @app]
  # end

  # def oban_adapter_app(adapter) do
  #   oban_adapter(adapter)[:app] || @app
  # end

  # def oban(adapter) do
  #   Application.get_env(adapter_app(adapter), Oban) || []
  # end

  # def oban_name do
  #   oban()[:name] || Uppy.Oban
  # end
end
