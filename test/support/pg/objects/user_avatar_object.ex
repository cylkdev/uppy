defmodule Uppy.Support.PG.Objects.UserAvatarObject do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_avatar_objects" do
    belongs_to :user, Uppy.Support.PG.Accounts.User
    belongs_to :user_avatar, Uppy.Support.PG.Accounts.UserAvatar

    field :unique_identifier, :string
    field :key, :string
    field :filename, :string
    field :e_tag, :string
    field :upload_id, :string

    field :content_length, :integer
    field :content_type, :string
    field :last_modified, :utc_datetime

    field :archived, :boolean, default: false
    field :archived_at, :utc_datetime

    timestamps()
  end

  @required_fields [
    :key,
    :filename,
    :unique_identifier,
    :user_avatar_id,
    :user_id
  ]

  @allowed_fields [
    :archived,
    :archived_at,
    :content_length,
    :content_type,
    :e_tag,
    :last_modified,
    :upload_id
  ] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assoc_id)
    |> unique_constraint(:unique_identifier)
    |> unique_constraint(:key)
    |> unique_constraint([:key, :upload_id])
    |> validate_length(:filename, min: 1, max: 256)
    |> validate_filename_format()
    |> EctoShorts.CommonChanges.preload_change_assoc(:user)
    |> EctoShorts.CommonChanges.preload_change_assoc(:user_avatar)
  end

  # This regex validates that a filename is compliant with DNS,
  # web-safe characters, XML parsers, and other APIs.
  #
  # Read more: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
  @filename_regex ~r|^[[:alnum:]\!\-\_\.\*\'\(\)]+$|u

  defp validate_filename_format(changeset) do
    case get_change(changeset, :filename) do
      nil ->
        changeset

      filename ->
        filename = String.trim(filename)

        if Regex.match?(@filename_regex, filename) do
          put_change(changeset, :filename, filename)
        else
          add_error(
            changeset,
            :filename,
            Enum.join([
              "The filename contains invalid characters, ",
              "It can only contain 0-9, a-z, A-Z, !, -, _, ., *, ', (, )"
            ]),
            validation: :format
          )
        end
    end
  end
end
