defmodule Uppy.Support.PG.Accounts.UserAvatar do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_avatars" do
    belongs_to :user_profile, Uppy.Support.PG.Accounts.UserProfile

    has_one :object, {"user_avatar_objects", Uppy.Support.PG.Object}

    field :name, :string
    field :description, :string

    timestamps()
  end

  @allowed_fields [
    :description,
    :name,
    :user_profile_id
  ]

  @doc false
  def changeset(model_or_changeset, attrs) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> EctoShorts.CommonChanges.preload_change_assoc(:user_profile)
    |> EctoShorts.CommonChanges.preload_change_assoc(:object)
  end
end
