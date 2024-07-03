defmodule Uppy.Adapters.ObjectKey.TemporaryObject do
  @moduledoc """
  ...
  """
  alias Uppy.Adapter

  @behaviour Adapter.ObjectKey

  @config Application.compile_env(Uppy.Config.app(), __MODULE__, [])

  @name @config[:name] || "temp"

  unless is_binary(@name) do
    raise ArgumentError,
          "option `:name` in module #{__MODULE__} must be a string, got: #{inspect(@name)}"
  end

  @path_definition [
    key: [
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
    partition: [
      type: :string,
      doc: "object path suffix"
    ],
    basename: [
      type: :string,
      doc: "name of the object without any directory path or file extension"
    ]
  ]

  @impl Adapter.ObjectKey
  def path?(attrs) do
    attrs
    |> NimbleOptions.validate!(@path_definition)
    |> Map.new()
    |> Map.fetch!(:key)
    |> String.starts_with?("#{@name}/")
  end

  @impl Adapter.ObjectKey
  def build(attrs) do
    attrs
    |> NimbleOptions.validate!(@build_definition)
    |> Map.new()
    |> transform()
  end

  defp transform(%{id: id, partition: partition, basename: basename}) do
    object_key(id, partition, basename)
  end

  defp transform(%{id: id, partition: partition}) do
    object_key(id, partition)
  end

  defp transform(%{id: id}) do
    object_key(id)
  end

  def object_key(id, partition, basename) do
    "#{object_key(id, partition)}/#{URI.encode_www_form(basename)}"
  end

  def object_key(id, partition) do
    "#{object_key(id)}-#{partition}"
  end

  def object_key(id) do
    id = id |> maybe_reverse_id() |> URI.encode_www_form()

    "#{@name}/#{id}"
  end

  defp maybe_reverse_id(id) do
    case Keyword.get(@config, :reversed_id_enabled, true) do
      true -> String.reverse(id)
      false -> id
    end
  end
end
