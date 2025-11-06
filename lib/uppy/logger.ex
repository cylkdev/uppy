defmodule Uppy.Logger do
  require Logger

  def debug(prefix, message, meta \\ []) do
    prefix
    |> format_message(message)
    |> Logger.debug(meta)
  end

  def info(prefix, message, meta \\ []) do
    prefix
    |> format_message(message)
    |> Logger.info(meta)
  end

  def warning(prefix, message, meta \\ []) do
    prefix
    |> format_message(message)
    |> Logger.warning(meta)
  end

  def error(prefix, message, meta \\ []) do
    prefix
    |> format_message(message)
    |> Logger.error(meta)
  end

  defp format_message(prefix, message) do
    "[#{prefix}] #{message}"
  end
end
