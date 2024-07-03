defmodule Uppy.Support.PG.Accounts do
  @moduledoc false
  alias EctoShorts.Actions

  alias Uppy.Support.PG.Accounts.{
    User,
    UserAvatar,
    UserProfile
  }

  # user

  def create_user(params, options \\ []) do
    Actions.create(User, params, options)
  end

  def find_user(params, options \\ []) do
    Actions.find(User, params, options)
  end

  def update_user(id_or_schema_data, params, options \\ []) do
    Actions.update(User, id_or_schema_data, params, options)
  end

  def delete_user(%_{} = schema_data, options) do
    Actions.delete(schema_data, options)
  end

  def delete_user(id, options) do
    Actions.delete(User, id, options)
  end

  def delete_user(id_or_schema_data) do
    delete_user(id_or_schema_data, [])
  end

  # user_profile

  def create_user_profile(params, options \\ []) do
    Actions.create(UserProfile, params, options)
  end

  def find_user_profile(params, options \\ []) do
    Actions.find(UserProfile, params, options)
  end

  def update_user_profile(id_or_schema_data, params, options \\ []) do
    Actions.update(UserProfile, id_or_schema_data, params, options)
  end

  def delete_user_profile(%_{} = schema_data, options) do
    Actions.delete(schema_data, options)
  end

  def delete_user_profile(id, options) do
    Actions.delete(UserProfile, id, options)
  end

  def delete_user_profile(id_or_schema_data) do
    delete_user_profile(id_or_schema_data, [])
  end

  # user_avatar

  def create_user_avatar(params, options \\ []) do
    Actions.create(UserAvatar, params, options)
  end

  def find_user_avatar(params, options \\ []) do
    Actions.find(UserAvatar, params, options)
  end

  def update_user_avatar(id_or_schema_data, params, options \\ []) do
    Actions.update(UserAvatar, id_or_schema_data, params, options)
  end

  def delete_user_avatar(%_{} = schema_data, options) do
    Actions.delete(schema_data, options)
  end

  def delete_user_avatar(id, options) do
    Actions.delete(UserAvatar, id, options)
  end

  def delete_user_avatar(id_or_schema_data) do
    delete_user_avatar(id_or_schema_data, [])
  end
end
