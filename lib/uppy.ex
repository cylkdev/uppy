defmodule Uppy do
  @moduledoc false
  alias Uppy.{Core, Uploader}

  @doc """
  ...
  """
  def start_link(opts \\ []) do
    opts
    |> Keyword.put_new(:name, __MODULE__)
    |> Uppy.Supervisor.start_link()
  end

  @doc """
  ...
  """
  def child_spec(opts) do
    opts
    |> Keyword.put_new(:name, __MODULE__)
    |> Uppy.Supervisor.child_spec()
  end

  @doc """
  ...
  """
  def move_to_destination(uploader, dest_object, params_or_struct, opts) do
    Uploader.move_to_destination(
      uploader,
      dest_object,
      params_or_struct,
      opts
    )
  end

  @doc """
  ...
  """
  def move_to_destination(bucket, query, dest_object, params_or_struct, opts) do
    Core.move_to_destination(
      bucket,
      query,
      dest_object,
      params_or_struct,
      opts
    )
  end

  @doc """
  ...
  """
  def find_parts(uploader, params_or_struct, opts) do
    Uploader.find_parts(uploader, params_or_struct, opts)
  end

  @doc """
  ...
  """
  def find_parts(bucket, query, params_or_struct, opts) do
    Core.find_parts(bucket, query, params_or_struct, opts)
  end

  @doc """
  ...
  """
  def sign_part(uploader, params_or_struct, part_number, opts) do
    Uploader.sign_part(
      uploader,
      params_or_struct,
      part_number,
      opts
    )
  end

  @doc """
  ...
  """
  def sign_part(bucket, query, params_or_struct, part_number, opts) do
    Core.sign_part(bucket, query, params_or_struct, part_number, opts)
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
        bucket,
        path_params,
        query,
        find_params,
        update_params,
        parts,
        opts
      ) do
    Core.complete_multipart_upload(
      bucket,
      path_params,
      query,
      find_params,
      update_params,
      parts,
      opts
    )
  end

  @doc """
  ...
  """
  def complete_multipart_upload(
        uploader,
        path_params,
        params_or_struct,
        update_params,
        parts,
        opts
      ) do
    Uploader.complete_multipart_upload(
      uploader,
      path_params,
      params_or_struct,
      update_params,
      parts,
      opts
    )
  end

  @doc """
  ...
  """
  def abort_multipart_upload(uploader, params_or_struct, update_params, opts) do
    Uploader.abort_multipart_upload(
      uploader,
      params_or_struct,
      update_params,
      opts
    )
  end

  @doc """
  ...
  """
  def abort_multipart_upload(bucket, query, find_params, update_params, opts) do
    Core.abort_multipart_upload(
      bucket,
      query,
      find_params,
      update_params,
      opts
    )
  end

  @doc """
  ...
  """
  def create_multipart_upload(uploader, path_params, create_params, opts) do
    Uploader.create_multipart_upload(
      uploader,
      path_params,
      create_params,
      opts
    )
  end

  @doc """
  ...
  """
  def create_multipart_upload(
        bucket,
        path_params,
        query,
        create_params,
        opts
      ) do
    Core.create_multipart_upload(
      bucket,
      query,
      create_params,
      path_params,
      opts
    )
  end

  @doc """
  ...
  """
  def complete_upload(uploader, params_or_struct, update_params, path_params, opts) do
    Uploader.complete_upload(
      uploader,
      params_or_struct,
      update_params,
      path_params,
      opts
    )
  end

  @doc """
  ...
  """
  def complete_upload(
        bucket,
        path_params,
        query,
        params_or_struct,
        update_params,
        opts
      ) do
    Core.complete_upload(
      bucket,
      path_params,
      query,
      params_or_struct,
      update_params,
      opts
    )
  end

  @doc """
  ...
  """
  def abort_upload(uploader, find_params, update_params, opts) do
    Uploader.abort_upload(
      uploader,
      find_params,
      update_params,
      opts
    )
  end

  @doc """
  ...
  """
  def abort_upload(bucket, query, params_or_struct, update_params, opts) do
    Core.abort_upload(
      bucket,
      query,
      params_or_struct,
      update_params,
      opts
    )
  end

  @doc """
  ...
  """
  def create_upload(uploader, path_params, create_params, opts) do
    Uploader.create_upload(
      uploader,
      path_params,
      create_params,
      opts
    )
  end

  @doc """
  ...
  """
  def create_upload(bucket, path_params, query, create_params, opts) do
    Core.create_upload(
      bucket,
      path_params,
      query,
      create_params,
      opts
    )
  end
end
