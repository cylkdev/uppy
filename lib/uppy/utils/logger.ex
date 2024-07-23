defmodule Uppy.Utils.Logger do
  @moduledoc false
  require Logger

  @spec debug(binary, binary) :: :ok
  def debug(identifier, message) do
    identifier
    |> format_message(message)
    |> Logger.debug()
  end

  @spec warning(binary, binary) :: :ok
  def warning(identifier, message) do
    identifier
    |> format_message(message)
    |> Logger.warning()
  end

  @spec warn(binary, binary) :: :ok
  def warn(identifier, message) do
    warning(identifier, message)
  end

  defp format_message(identifier, message) do
    "[#{identifier}] #{message}"
  end
end
