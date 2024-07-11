defmodule Uppy.Utils.Logger do
  @moduledoc false
  require Logger

  @spec debug(binary, binary) :: :ok
  def debug(identifier, message), do: log(:debug, identifier, message)

  @spec info(binary, binary) :: :ok
  def info(identifier, message), do: log(:info, identifier, message)

  @spec warn(binary, binary) :: :ok
  def warn(identifier, message), do: log(:warn, identifier, message)

  @spec error(binary, binary) :: :ok
  def error(identifier, message), do: log(:error, identifier, message)

  @spec warn_with_stack(binary, binary) :: :ok
  def warn_with_stack(identifier, message) do
    log_with_stacktrace(:warn, identifier, message)
  end

  @spec debug_with_stack(binary, binary) :: :ok
  def debug_with_stack(identifier, message) do
    log_with_stacktrace(:debug, identifier, message)
  end

  @spec info_with_stack(binary, binary) :: :ok
  def info_with_stack(identifier, message) do
    log_with_stacktrace(:info, identifier, message)
  end

  @spec error_with_stack(binary, binary) :: :ok
  def error_with_stack(identifier, message) do
    log_with_stacktrace(:error, identifier, message)
  end

  defp log_with_stacktrace(type, identifier, error) do
    log_error(type, error_message(identifier, error))
    log_error(type, Exception.format_stacktrace())
  end

  defp log(type, identifier, error) do
    log_error(type, error_message(identifier, error))
  end

  defp log_error(:debug, message), do: Logger.debug(message)
  defp log_error(:info, message), do: Logger.debug(message)
  defp log_error(:warn, message), do: Logger.warning(message)
  defp log_error(:error, message), do: Logger.error(message)

  defp error_message(identifier, message) when is_atom(identifier) do
    error_message(inspect(identifier), message)
  end

  defp error_message(identifier, %{code: code, message: message, details: details}) do
    "[#{identifier}] #{code}: #{message}\n#{inspect(details, pretty: true)}"
  end

  defp error_message(identifier, %{code: code, message: message}) do
    "[#{identifier}] #{code}: #{message}"
  end

  defp error_message(identifier, message) when is_binary(message) do
    "[#{identifier}] #{message}"
  end

  defp error_message(identifier, message) do
    "[#{identifier}] #{inspect(message)}"
  end
end
