# defmodule Uppy.Schemas.UserProfile do
#   @moduledoc false
#   use Ecto.Schema

#   import Ecto.Changeset

#   schema "user_profiles" do
#     belongs_to :user, Uppy.Schemas.User

#     field :display_name, :string

#     timestamps()
#   end

#   @allowed_fields [
#     :display_name,
#     :user_id
#   ]

#   @doc false
#   def changeset(model_or_changeset, attrs) do
#     model_or_changeset
#     |> cast(attrs, @allowed_fields)
#     |> EctoShorts.CommonChanges.preload_change_assoc(:user)
#   end
# end
