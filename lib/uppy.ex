defmodule Uppy do
  @moduledoc """
  Documentation for `Uppy`.
  """

  @type adapter :: module()
  @type schema :: module()

  @type params :: map()
  @type body :: term()
  @type max_age_in_seconds :: non_neg_integer()
  @type options :: Keyword.t()

  @type http_method ::
          :get
          | :head
          | :post
          | :put
          | :delete
          | :connect
          | :options
          | :trace
          | :patch

  @type bucket :: String.t()
  @type prefix :: String.t()
  @type object :: String.t()

  @type e_tag :: String.t()
  @type upload_id :: String.t()
  @type marker :: String.t()
  @type maybe_marker :: marker() | nil
  @type part_number :: non_neg_integer()
  @type part :: {part_number(), e_tag()}
  @type parts :: list(part())

  ## Shared API

  defdelegate delete_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate run_pipeline(
    pipeline_module_or_pipeline,
    bucket,
    resource_name,
    schema,
    params_or_schema_data,
    options \\ []
  ), to: Uppy.Core

  defdelegate delete_object_if_upload_not_found(bucket, schema, key, options \\ []), to: Uppy.Core

  ## Multipart Upload API

  defdelegate presigned_part(bucket, schema, params, part_number, options \\ []) , to: Uppy.Core

  defdelegate find_parts(bucket, schema, params, maybe_next_part_number_marker, options \\ []), to: Uppy.Core

  defdelegate find_permanent_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_completed_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_temporary_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate complete_multipart_upload(
    bucket,
    resource_name,
    pipeline_module,
    schema,
    find_params,
    update_params,
    parts,
    options \\ []
  ), to: Uppy.Core

  defdelegate abort_multipart_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate start_multipart_upload(bucket, partition_id, schema, params, options \\ []), to: Uppy.Core

  ## Non-Multipart Upload API

  defdelegate find_permanent_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_completed_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_temporary_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate complete_upload(
    bucket,
    resource_name,
    pipeline_module,
    schema,
    find_params,
    update_params,
    options \\ []
  ), to: Uppy.Core

  defdelegate abort_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate start_upload(bucket, partition_id, schema, params, options \\ []), to: Uppy.Core
end
