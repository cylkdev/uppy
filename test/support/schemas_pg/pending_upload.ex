defmodule Uppy.SchemasPG.PendingUpload do
  use Ecto.Schema

  import Ecto.Changeset

  schema "pending_uploads" do
    field :state, :string, default: "pending"
    field :unique_identifier, :string
    field :key, :string
    field :upload_id, :string

    field :content_length, :integer
    field :content_type, :string
    field :last_modified, :naive_datetime
    field :etag, :string

    has_one :upload, Uppy.SchemasPG.Upload

    timestamps()
  end

  @required_fields [:state, :unique_identifier, :key]

  @allowed_fields [
                    :upload_id,
                    :content_length,
                    :content_type,
                    :last_modified,
                    :etag
                  ] ++ @required_fields

  @doc false
  def changeset(pending_upload, attrs) do
    pending_upload
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
