defmodule Uppy.Adapter.Uploader do
  @type t_res :: {:ok, term()} | {:error, term()}

  @type queryable :: module()
  @type object :: String.t()
  @type params :: map()
  @type options :: options()

  @type upload_id :: Uppy.upload_id()
  @type maybe_marker :: Uppy.maybe_marker()
  @type part_number :: Uppy.part_number()
  @type part :: Uppy.part()
  @type parts :: Uppy.parts()

  @callback action_adapter :: term()

  @type pipeline :: list()

  @callback queryable :: term()

  @callback resource_name :: term()

  @callback pipeline :: pipeline()

  @callback storage_adapter :: term()

  @callback permanent_scope_adapter :: term()

  @callback temporary_scope_adapter :: term()

  @callback scheduler_adapter :: term()

  @callback bucket :: term()

  @doc """
  ...
  """
  @callback presigned_part(
              params :: params(),
              part_number :: part_number(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_parts(
              params :: params(),
              maybe_next_part_number_marker :: maybe_marker(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback complete_multipart_upload(
              params :: params(),
              parts :: parts(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback abort_multipart_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback start_multipart_upload(
              upload_params :: params(),
              create_params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback run_pipeline(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback complete_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback garbage_collect_object(
              object :: object(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback abort_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback start_upload(
              upload_params :: params(),
              create_params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_object_and_update_upload_e_tag(
              params_or_schema_data :: map() | struct(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_permanent_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_completed_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @doc """
  ...
  """
  @callback find_temporary_upload(
              params :: params(),
              options :: options()
            ) :: t_res()
end
