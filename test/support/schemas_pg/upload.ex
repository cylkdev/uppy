defmodule Uppy.SchemasPG.Upload do
  use Ecto.Schema

  import Ecto.Changeset

  schema "uploads" do
    field :unique_identifier, :string
    field :key, :string

    field :content_length, :integer
    field :content_type, :string
    field :last_modified, :naive_datetime
    field :etag, :string

    belongs_to :pending_upload, Uppy.SchemasPG.PendingUpload

    timestamps()
  end

  @required_fields []
  @allowed_fields [
                    :unique_identifier,
                    :key,
                    :pending_upload_id,
                    :content_length,
                    :content_type,
                    :last_modified,
                    :etag
                  ] ++ @required_fields

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
