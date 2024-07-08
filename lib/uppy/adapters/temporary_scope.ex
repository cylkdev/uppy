defmodule Uppy.Adapters.TemporaryScope do
  @moduledoc """
  ...
  """

  alias Uppy.Adapter

  @behaviour Adapter.TemporaryScope

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @resource_name Keyword.get(@config, :resource_name, "user")

  @prefix Keyword.get(@config, :prefix, "temp")

  @doc """
  ...
  """
  @impl Adapter.TemporaryScope
  @spec path?(binary()) :: boolean()
  def path?(path), do: String.starts_with?(path, @prefix)

  @doc """
  ...
  """
  @impl Adapter.TemporaryScope
  @spec prefix(binary(), binary()) :: binary()
  def prefix(id, basename) do
    prefix(id) <> "/" <> URI.encode_www_form(basename)
  end

  @spec prefix(binary()) :: binary()
  def prefix(id) do
    id = id |> reverse() |> URI.encode_www_form()

    Path.join([prefix(), "/", "#{id}-#{@resource_name}"])
  end

  @spec prefix :: binary()
  def prefix, do: @prefix

  defp reverse(id) do
    case Keyword.get(@config, :reverse, true) do
      true -> String.reverse(id)
      false -> id
    end
  end
end
