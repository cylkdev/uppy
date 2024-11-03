defmodule Uppy.Schemas.FileInfoAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @default_status :pending
  @status_list [
    :pending,
    :available,
    :processing,
    :completed,
    :discarded,
    :cancelled
  ]

  schema "abstract table: file_infos" do
    field :status, Ecto.Enum, values: @status_list, default: @default_status
    field :key, :string

    field :content_length, :integer
    field :content_type, :string
    field :e_tag, :string
    field :last_modified, :utc_datetime
    field :upload_id, :string

    field :assoc_id, :integer
    field :filename, :string
    field :unique_identifier, :string

    belongs_to :user, Uppy.Schemas.User

    timestamps()
  end

  @required_fields [
    :key
  ]

  @allowed_fields [
    :assoc_id,
    :content_length,
    :content_type,
    :e_tag,
    :filename,
    :last_modified,
    :status,
    :unique_identifier,
    :user_id,
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
    |> EctoShorts.CommonChanges.preload_change_assoc(:user)
  end
end
