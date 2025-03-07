defmodule Uppy.PathBuilder do
  @moduledoc false

  @callback build_object_path(
              action :: atom(),
              struct :: struct(),
              unique_identifier :: binary(),
              params :: map()
            ) :: {basename :: binary(), path :: binary()}

  @callback build_object_path(
              action :: atom(),
              filename :: binary(),
              params :: map()
            ) :: {basename :: binary(), path :: binary()}

  @default_path_builder_adapter Uppy.StoragePathBuilder

  def build_object_path(action, struct, unique_identifier, params, opts) do
    adapter(opts).build_object_path(action, struct, unique_identifier, params)
  end

  def build_object_path(action, filename, params, opts) do
    adapter(opts).build_object_path(action, filename, params)
  end

  defp adapter(opts) do
    opts[:path_builder_adapter] || @default_path_builder_adapter
  end
end
