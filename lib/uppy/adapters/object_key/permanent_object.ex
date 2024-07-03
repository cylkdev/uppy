defmodule Uppy.Adapters.ObjectKey.PermanentObject do
  @moduledoc """
  ...
  """

  alias Uppy.Adapter

  @behaviour Adapter.ObjectKey

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @prefix @config[:prefix] || ""

  unless is_binary(@prefix) do
    raise ArgumentError,
          "option `:prefix` in module #{__MODULE__} must be a string, got: #{inspect(@prefix)}"
  end

  @path_definition [
    key: [
      type: :string,
      required: true,
      doc: "Resource name"
    ],
    id: [
      type: :string,
      required: true,
      doc: "Resource name"
    ],
    resource: [
      type: :string,
      required: true,
      doc: "Resource name"
    ]
  ]

  @build_definition [
    id: [
      type: :string,
      required: true,
      doc: "ID"
    ],
    resource: [
      type: :string,
      doc: "Resource name"
    ],
    basename: [
      type: :string,
      doc: "Resource name"
    ]
  ]

  @impl Adapter.ObjectKey
  def path?(attrs) do
    attrs
    |> NimbleOptions.validate!(@path_definition)
    |> Map.new()
    |> path_starts_with_prefix?()
  end

  defp path_starts_with_prefix?(%{key: key, id: id, resource: resource}) do
    String.starts_with?(key, object_key(id, resource))
  end

  @impl Adapter.ObjectKey
  def build(attrs) do
    attrs
    |> NimbleOptions.validate!(@build_definition)
    |> Map.new()
    |> transform()
  end

  defp transform(%{id: id, resource: resource, basename: basename}) do
    object_key(id, resource, basename)
  end

  defp transform(%{id: id, resource: resource}) do
    object_key(id, resource)
  end

  defp transform(%{id: id}) do
    object_key(id)
  end

  def object_key(id, resource, basename) do
    "#{object_key(id, resource)}/#{URI.encode_www_form(basename)}"
  end

  def object_key(id, resource) do
    "#{object_key(id)}-#{URI.encode_www_form(resource)}"
  end

  def object_key(id) do
    id |> maybe_reverse_id() |> URI.encode_www_form()
  end

  defp maybe_reverse_id(id) do
    case Keyword.get(@config, :reversed_id_enabled, true) do
      true -> String.reverse(id)
      false -> id
    end
  end
end
