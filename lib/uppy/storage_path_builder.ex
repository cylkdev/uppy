defmodule Uppy.StoragePathBuilder do
  @moduledoc false

  @callback build_storage_path(
              action :: atom(),
              struct :: struct(),
              unique_identifier :: binary(),
              params :: map(),
              opts :: keyword()
            ) :: {basename :: binary(), path :: binary()}

  @callback build_storage_path(
              action :: atom(),
              filename :: binary(),
              params :: map(),
              opts :: keyword()
            ) :: {basename :: binary(), path :: binary()}

  @default_path_builder_adapter Uppy.StoragePathBuilder.CommonStoragePath

  def build_storage_path(action, struct, unique_identifier, params, opts) do
    adapter(opts).build_storage_path(action, struct, unique_identifier, params, opts)
  end

  def build_storage_path(action, filename, params, opts) do
    adapter(opts).build_storage_path(action, filename, params, opts)
  end

  defp adapter(opts) do
    opts[:path_builder_adapter] || @default_path_builder_adapter
  end
end
