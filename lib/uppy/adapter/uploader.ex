defmodule Uppy.Adapter.Uploader do
  @type t_res :: {:ok, term()} | {:error, term()}

  @type core :: Uppy.Core.t()
  @type queryable :: module()
  @type object :: String.t()
  @type params :: map()
  @type options :: Keyword.t()

  @type upload_id :: Uppy.upload_id()
  @type maybe_marker :: Uppy.maybe_marker()
  @type part_number :: Uppy.part_number()
  @type part :: Uppy.part()
  @type parts :: Uppy.parts()

  @type pipeline :: list()

  @doc """
  ...
  """
  @callback core :: core()

  @doc """
  ...
  """
  @callback core(term()) :: term()

  @doc """
  ...
  """
  @callback pipeline :: pipeline()

  @doc """
  ...
  """
  @callback presigned_part(
              params :: params(),
              part_number :: part_number()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_parts(
              params :: params(),
              maybe_next_part_number_marker :: maybe_marker()
            ) :: t_res()

  @doc """
  ...
  """
  @callback complete_multipart_upload(
              params :: params(),
              parts :: parts()
            ) :: t_res()

  @doc """
  ...
  """
  @callback abort_multipart_upload(params :: params()) :: t_res()

  @doc """
  ...
  """
  @callback start_multipart_upload(
              upload_params :: params(),
              create_params :: params()
            ) :: t_res()

  @doc """
  ...
  """
  @callback move_temporary_to_permanent_upload(params :: params()) :: t_res()

  @doc """
  ...
  """
  @callback complete_upload(params :: params()) :: t_res()

  @doc """
  ...
  """
  @callback garbage_collect_object(object :: object()) :: t_res()

  @doc """
  ...
  """
  @callback abort_upload(params :: params()) :: t_res()

  @doc """
  ...
  """
  @callback start_upload(upload_params :: params(), create_params :: params()) :: t_res()
end
