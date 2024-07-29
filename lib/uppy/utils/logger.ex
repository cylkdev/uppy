defmodule Uppy.Utils.Logger do
  @moduledoc false
  require Logger

  @doc false
  @spec debug(binary, binary, keyword) :: :ok
  def debug(identifier, message, opts \\ []) do
    identifier
    |> format_message(message, opts[:binding])
    |> Logger.debug(opts[:metadata] || [])
  end

  @doc false
  @spec warning(binary, binary, keyword) :: :ok
  def warning(identifier, message, opts \\ []) do
    identifier
    |> format_message(message, opts[:binding])
    |> Logger.warning(opts[:metadata] || [])
  end

  @doc false
  @spec warn(binary, binary, keyword) :: :ok
  def warn(identifier, message, opts \\ []) do
    warning(identifier, message, opts)
  end

  @doc false
  @spec error(binary, binary, keyword) :: :ok
  def error(identifier, message, opts \\ []) do
    identifier
    |> format_message(message, opts[:binding])
    |> Logger.error(opts[:metadata] || [])
  end

  defp format_message(identifier, message) do
    "[#{identifier}] #{message}"
  end

  defp format_message(identifier, message, binding) do
    message =
      if binding do
        message <> " | " <> join_binding(binding)
      else
        message
      end

    format_message(identifier, message)
  end

  defp join_binding(binding) do
    Enum.map_join(binding, ", ", fn {k, v} -> "#{to_string(k)}=#{inspect(v)}" end)
  end
end
