defmodule Uppy.PathBuilder do
  @moduledoc false

  @type basename :: binary()
  @type filename :: binary()
  @type path :: binary()
  @type unique_identifier :: binary()
  @type opts :: keyword()

  @callback build_permanent_object_path(
              struct :: struct(),
              unique_identifier :: binary(),
              opts :: opts()
            ) :: {basename :: basename(), path :: path()}

  @callback build_temporary_object_path(
              filename :: filename(),
              opts :: opts()
            ) :: {basename :: basename(), path :: path()}

  @default_path_builder_adapter Uppy.PathBuilders.StoragePathBuilder

  def build_permanent_object_path(struct, unique_identifier, opts) do
    adapter(opts).build_permanent_object_path(struct, unique_identifier, opts)
  end

  def build_temporary_object_path(filename, opts) do
    adapter(opts).build_temporary_object_path(filename, opts)
  end

  defp adapter(opts) do
    opts[:path_builder_adapter] || @default_path_builder_adapter
  end
end
