defmodule Uppy.Schemas.Upload do
  use Ecto.Schema

  import Ecto.Changeset

  @pending :pending
  @completed :completed
  @aborted :aborted
  @states [@pending, @completed, @aborted]

  schema "uploads" do
    field :state, Ecto.Enum, values: @states, default: @pending
    field :label, :string
    field :promoted, :boolean, default: false
    field :unique_identifier, :string
    field :bucket, :string
    field :key, :string
    field :upload_id, :string
    field :filename, :string
    field :content_length, :integer
    field :content_type, :string
    field :last_modified, :utc_datetime
    field :etag, :string

    belongs_to :parent, Uppy.Schemas.Upload

    timestamps()
  end

  @required_fields [:bucket, :label, :key]
  @allowed_fields [
                    :filename,
                    :unique_identifier,
                    :upload_id,
                    :content_length,
                    :content_type,
                    :last_modified,
                    :etag,
                    :promoted,
                    :state,
                    :parent_id
                  ] ++ @required_fields

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:key)
  end
end
