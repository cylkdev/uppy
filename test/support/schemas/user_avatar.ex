defmodule Uppy.Schemas.UserAvatar do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_avatars" do
    field :name, :string
    field :description, :string

    has_one :file_info, {"user_avatar_file_infos", Uppy.Schemas.FileInfoAbstract},
      foreign_key: :assoc_id

    timestamps()
  end

  @allowed_fields [
    :description,
    :name
  ]

  @doc false
  def changeset(model_or_changeset, attrs) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> EctoShorts.CommonChanges.preload_change_assoc(:file_info)
  end
end
