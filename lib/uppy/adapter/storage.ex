defmodule Uppy.Adapter.Storage do
  @moduledoc """
  Storage Adapter
  """

  @type t_res :: {:ok, term()} | {:error, term()}

  @type adapter :: Uppy.adapter()

  @type opts :: Uppy.opts()

  @type bucket :: binary()

  @type prefix :: binary()

  @type object :: binary()

  @type body :: term()

  @type http_method :: atom()

  @type e_tag :: binary()

  @type upload_id :: binary()

  @type marker :: binary()

  @type part_number :: pos_integer()

  @type part :: {part_number(), e_tag()}

  @type parts :: list(part())

  @doc """
  ...
  """
  @callback list_objects(
    bucket :: bucket(),
    prefix :: prefix(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback get_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback head_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback presigned_url(
    bucket :: bucket(),
    http_method :: http_method(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback list_multipart_uploads(
    bucket :: bucket(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback initiate_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback list_parts(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback abort_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback complete_multipart_upload(
    bucket :: bucket(),
    object :: object(),
    upload_id :: upload_id(),
    parts :: parts(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback put_object_copy(
    dest_bucket :: bucket(),
    destination_object :: object(),
    src_bucket :: bucket(),
    source_object :: object(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback put_object(
    bucket :: bucket(),
    object :: object(),
    body :: body(),
    opts :: opts()
  ) :: t_res()

  @doc """
  ...
  """
  @callback delete_object(
    bucket :: bucket(),
    object :: object(),
    opts :: opts()
  ) :: t_res()
end
