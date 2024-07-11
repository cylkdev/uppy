defmodule Uppy.Config do
  @moduledoc false
  @app :uppy

  @spec app :: atom()
  def app, do: @app

  @doc false
  @spec atomize_keys? :: module()
  def atomize_keys?, do: Application.get_env(@app, :atomize_keys?) || true

  @doc false
  @spec oban :: Keyword.t()
  def oban, do: Application.get_env(@app, Oban, [])

  @doc false
  @spec error_message_adapter :: module()
  def error_message_adapter do
    Application.get_env(@app, :error_message_adapter) || ErrorMessage
  end

  @doc false
  @spec action_adapter :: module()
  def action_adapter do
    Application.get_env(@app, :action_adapter) || Uppy.Adapters.Action
  end

  @doc false
  @spec http_adapter :: module()
  def http_adapter do
    Application.get_env(@app, :http_adapter) || Uppy.Adapters.HTTP.Finch
  end

  @doc false
  @spec json_adapter :: module()
  def json_adapter, do: Application.get_env(@app, :json_adapter) || Jason

  @doc false
  @spec thumbor_adapter :: module()
  def thumbor_adapter do
    Application.get_env(@app, :thumbor_adapter) || Uppy.Adapters.Thumbor
  end
end
