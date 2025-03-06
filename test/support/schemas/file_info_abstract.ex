defmodule Uppy.Support.Schemas.FileInfoAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @states [
    :aborted,
    :completed,
    :expired,
    :pending,
    :processing,
    :ready
  ]

  schema "abstract table: file_infos" do
    field :state, Ecto.Enum, values: @states

    field :assoc_id, :integer

    field :filename, :string
    field :key, :string
    field :upload_id, :string
    field :unique_identifier, :string

    field :content_length, :integer
    field :content_type, :string
    field :e_tag, :string
    field :last_modified, :utc_datetime

    timestamps()
  end

  @required_fields [
    :filename,
    :key
  ]

  @allowed_fields [
                    :assoc_id,
                    :state,
                    :content_length,
                    :content_type,
                    :e_tag,
                    :last_modified,
                    :unique_identifier,
                    :upload_id
                  ] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assoc_id)
  end
end
