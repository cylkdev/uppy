defmodule Uppy.Support.Factory.Objects.UserAvatarObject do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.Schemas.UserAvatarObject

  @impl FactoryEx
  def repo, do: Uppy.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(%{
      unique_identifier: "unique_identifier_#{FactoryEx.SchemaCounter.next("user_avatar_object_unique_identifier")}"
    }, attrs)
  end
end
