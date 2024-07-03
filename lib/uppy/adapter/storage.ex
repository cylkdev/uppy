defmodule Uppy.Adapter.Storage do
  @moduledoc """
  Storage Adapter
  """

  @type t_res :: {:ok, term()} | {:error, term()}

  @type adapter :: module()
  @type bucket :: String.t()
  @type prefix :: String.t()
  @type object :: String.t()
  @type body :: term()
  @type e_tag :: String.t()
  @type options :: options()
  @type http_method ::
          :get | :head | :post | :put | :delete | :connect | :options | :trace | :patch

  @type part_number :: non_neg_integer()
  @type upload_id :: String.t()
  @type marker :: String.t()
  @type maybe_marker :: marker() | nil
  @type part :: {part_number(), e_tag()}
  @type parts :: list(part())

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
  @callback presigned_part_upload(
              bucket :: bucket(),
              object :: object(),
              upload_id :: upload_id(),
              part_number :: part_number(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback presigned_download(
              bucket :: bucket(),
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback presigned_upload(
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
              dest_object :: object(),
              src_bucket :: bucket(),
              src_object :: object(),
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
