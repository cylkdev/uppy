defmodule Uppy.Adapters.PermanentScope do
  @moduledoc """
  ...
  """

  alias Uppy.Adapter

  @behaviour Adapter.PermanentScope

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @prefix Keyword.get(@config, :prefix, "")

  @doc """
  ...
  """
  @impl Adapter.PermanentScope
  @spec path?(binary()) :: boolean()
  def path?(path), do: String.starts_with?(path, @prefix)

  @doc """
  Uppy.Adapters.PermanentScope.prefix("1", "company", "image.jpeg")
  """
  @impl Adapter.PermanentScope
  @spec prefix(binary(), binary(), binary()) :: binary()
  def prefix(id, resource_name, basename) do
    prefix(id, resource_name) <> "/" <> URI.encode_www_form(basename)
  end

  @spec prefix(binary(), binary()) :: binary()
  def prefix(id, resource_name) do
    prefix(id) <> "-" <> URI.encode_www_form(resource_name)
  end

  @spec prefix(binary()) :: binary()
  def prefix(id) do
    id = id |> reverse() |> URI.encode_www_form()

    Path.join([prefix(), id])
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
