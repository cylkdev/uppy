defmodule Uppy.Adapter.Uploader do
  @type t_res :: {:ok, term()} | {:error, term()}

  @type provider :: Uppy.Core.t()
  @type queryable :: Ecto.Query.t()
  @type key :: String.t()
  @type params :: map()
  @type options :: Keyword.t()

  @type phases :: list()

  @callback provider :: provider()

  @callback queryable :: queryable()

  @callback pipeline :: phases()

  @callback move_upload_to_permanent_storage(
              params :: params(),
              options :: options()
            ) :: t_res()

  @callback complete_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @callback delete_aborted_upload_object(
              key :: key(),
              options :: options()
            ) :: t_res()

  @callback abort_upload(
              params :: params(),
              options :: options()
            ) :: t_res()

  @callback start_multipart_upload(
              upload_params :: params(),
              create_params :: params(),
              options :: options()
            ) :: t_res()

  @callback start_upload(
              upload_params :: params(),
              create_params :: params(),
              options :: options()
            ) :: t_res()
end
