defmodule Uppy.ObjectPath do
  @type adapter :: module()
  @type params :: map()
  @type opts :: keyword()
  @type id :: term()
  @type partition_name :: term()
  @type basename :: term()
  @type message :: binary()
  @type details :: map()
  @type path :: binary()

  @type t :: %{
    optional(atom()) => term(),
    id: id() | nil,
    partition_name: partition_name() | nil,
    basename: basename() | nil
  }

  @default_permanent_object_path_adapter Uppy.ObjectPaths.PermanentObjectPath
  @default_temporary_object_path_adapter Uppy.ObjectPaths.TemporaryObjectPath

  @callback build_object_path(
    id :: id(),
    partition_name :: partition_name(),
    basename :: basename(),
    opts :: opts()
  ) :: binary()

  @callback validate_object_path(
    path :: path(),
    opts :: opts()
  ) :: {:ok, object_path :: t()} | {:error, message :: message(), details :: details()}

  def build_object_path(adapter, id, partition_name, basename, opts) do
    adapter.build_object_path(id, partition_name, basename, opts)
  end

  def validate_object_path(adapter, path, opts) do
    adapter.validate_object_path(path, opts)
  end

  def validate_permanent_object_path(path, opts) do
    validate_object_path(
      opts[:permanent_object_path_adapter] || @default_permanent_object_path_adapter,
      path,
      opts
    )
  end

  def build_permanent_object_path(id, partition_name, basename, opts) do
    build_object_path(
      opts[:permanent_object_path_adapter] || @default_permanent_object_path_adapter,
      id,
      partition_name,
      basename,
      opts
    )
  end

  def validate_temporary_object_path(path, opts) do
    validate_object_path(
      opts[:temporary_object_path_adapter] || @default_temporary_object_path_adapter,
      path,
      opts
    )
  end

  def build_temporary_object_path(id, partition_name, basename, opts) do
    build_object_path(
      opts[:temporary_object_path_adapter] || @default_temporary_object_path_adapter,
      id,
      partition_name,
      basename,
      opts
    )
  end
end
