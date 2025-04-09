defmodule Uppy.PathBuilder do
  @moduledoc false

  @type action ::
          :create_upload
          | :complete_upload
          | :create_multipart_upload
          | :complete_multipart_upload

  @callback build_object_path(
              action :: action(),
              struct :: struct(),
              unique_identifier :: binary(),
              params :: map()
            ) :: %{basename: binary(), path: binary()}

  def build_object_path(module, action, struct, unique_identifier, params) do
    module.build_object_path(action, struct, unique_identifier, params)
  end
end
