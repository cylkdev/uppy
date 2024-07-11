defmodule Uppy.Adapter.Storage do
  @moduledoc """
  Storage Adapter
  """

  @type t_res :: {:ok, term()} | {:error, term()}

  @type adapter :: Uppy.adapter()
  @type bucket :: Uppy.bucket()
  @type prefix :: Uppy.prefix()
  @type object :: Uppy.object()
  @type body :: Uppy.body()
  @type options :: Uppy.options()

  @type http_method :: Uppy.http_method()

  @type e_tag :: Uppy.e_tag()
  @type upload_id :: Uppy.upload_id()
  @type maybe_marker :: Uppy.maybe_marker()
  @type part_number :: Uppy.part_number()
  @type part :: Uppy.part()
  @type parts :: Uppy.parts()

  @doc """
  ...
  """
  @callback list_objects(
              bucket :: bucket(),
              prefix :: prefix(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback get_object(
              bucket :: bucket(),
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback head_object(
              bucket :: bucket(),
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback presigned_url(
              bucket :: bucket(),
              http_method :: http_method(),
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback list_multipart_uploads(
              bucket :: bucket(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback initiate_multipart_upload(
              bucket :: bucket(),
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback list_parts(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback abort_multipart_upload(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback complete_multipart_upload(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              parts :: parts(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback put_object_copy(
              dest_bucket :: bucket(),
              destination_object :: object(),
              src_bucket :: bucket(),
              source_object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback put_object(
              bucket :: bucket(),
              object :: object(),
              body :: body(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback delete_object(
              bucket :: bucket(),
              object :: object(),
              options :: options()
            ) :: t_res()
end
