defmodule Uppy.PathBuilder do
  @moduledoc false

  @callback build_object_path(
              struct :: struct(),
              unique_identifier :: binary(),
              params :: map()
            ) :: {basename :: binary(), path :: binary()}

  @callback build_object_path(
              filename :: binary(),
              params :: map()
            ) :: {basename :: binary(), path :: binary()}

  @default_adapter Uppy.PathBuilders.CommonPathBuilder

  def build_object_path(struct, unique_identifier, params, opts) do
    adapter(opts).build_object_path(struct, unique_identifier, params)
  end

  def build_object_path(filename, params, opts) do
    adapter(opts).build_object_path(filename, params)
  end

  defp adapter(opts) do
    opts[:path_builder_adapter] || @default_adapter
  end
end
