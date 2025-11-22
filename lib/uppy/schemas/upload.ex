defmodule Uppy.Schemas.Upload do
  use Ecto.Schema

  import Ecto.Changeset

  @states [:pending, :aborted, :completed, :processing, :processed]

  schema "uploads" do
    field :state, Ecto.Enum, values: @states, default: :pending
    field :request_key, :string
    field :stored_key, :string
    field :upload_id, :string
    field :filename, :string
    field :content_length, :integer
    field :content_type, :string
    field :last_modified, :utc_datetime
    field :etag, :string

    timestamps()
  end

  @required_fields [:request_key, :stored_key, :filename]
  @allowed_fields [:upload_id, :content_length, :content_type, :last_modified, :etag] ++
                    @required_fields

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:request_key)
    |> unique_constraint(:stored_key)
  end
end
