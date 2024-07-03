defmodule Uppy.Support.PG.Objects do
  @moduledoc false
  alias EctoShorts.Actions

  alias Uppy.Support.PG.Objects.UserAvatarObject

  # user_avatar_object

  def create_user_avatar_object(params, options \\ []) do
    Actions.create(UserAvatarObject, params, options)
  end

  def find_user_avatar_object(params, options \\ []) do
    Actions.find(UserAvatarObject, params, options)
  end

  def update_user_avatar_object(id_or_schema_data, params, options \\ []) do
    Actions.update(UserAvatarObject, id_or_schema_data, params, options)
  end

  def delete_user_avatar_object(%_{} = schema_data, options) do
    Actions.delete(schema_data, options)
  end

  def delete_user_avatar_object(id, options) do
    Actions.delete(UserAvatarObject, id, options)
  end

  def delete_user_avatar_object(id_or_schema_data) do
    delete_user_avatar_object(id_or_schema_data, [])
  end
end
