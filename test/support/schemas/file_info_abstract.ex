defmodule Uppy.Schemas.FileInfoAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @default_state :pending
  @state_list [
    :pending,
    :available,
    :processing,
    :completed,
    :discarded,
    :cancelled
  ]

  schema "abstract table: file_infos" do
    field :state, Ecto.Enum, values: @state_list, default: @default_state
    field :key, :string
    field :upload_id, :string

    field :content_length, :integer
    field :content_type, :string
    field :e_tag, :string
    field :last_modified, :utc_datetime

    field :assoc_id, :integer

    timestamps()
  end

  @required_fields [
    :key
  ]

  @allowed_fields [
    :state,
    :upload_id,

    :assoc_id,
    :content_length,
    :content_type,
    :e_tag,
    # :filename,
    :last_modified,
    # :unique_identifier,
    # :user_id,
  ] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assoc_id)
  end
end
