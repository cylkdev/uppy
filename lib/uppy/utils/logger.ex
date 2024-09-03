defmodule Uppy.Utils.Logger do
  @moduledoc false
  require Logger

  @doc false
  @spec debug(binary, binary, keyword) :: :ok
  def debug(identifier, message, options \\ []) do
    identifier
    |> format_message(message, options[:binding])
    |> Logger.debug(options[:metadata] || [])
  end

  @doc false
  @spec warning(binary, binary, keyword) :: :ok
  def warning(identifier, message, options \\ []) do
    identifier
    |> format_message(message, options[:binding])
    |> Logger.warning(options[:metadata] || [])
  end

  @doc false
  @spec warn(binary, binary, keyword) :: :ok
  def warn(identifier, message, options \\ []) do
    warning(identifier, message, options)
  end

  @doc false
  @spec error(binary, binary, keyword) :: :ok
  def error(identifier, message, options \\ []) do
    identifier
    |> format_message(message, options[:binding])
    |> Logger.error(options[:metadata] || [])
  end

  defp format_message(identifier, message) do
    "[#{identifier}] #{message}"
  end

  defp format_message(identifier, message, binding) do
    message =
      if binding do
        message <> " " <> join_binding(binding)
      else
        message
      end

    format_message(identifier, message)
  end

  defp join_binding(binding) do
    Enum.map_join(binding, ", ", fn {k, v} -> "#{to_string(k)}=#{inspect(v)}" end)
  end
end
