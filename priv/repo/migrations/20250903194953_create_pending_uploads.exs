defmodule Uppy.Repo.Migrations.CreatePendingUploads do
  use Ecto.Migration

  def change do
    create table(:pending_uploads) do
      add :state, :string, default: "pending", null: false
      add :unique_identifier, :string, null: false
      add :key, :string, null: false
      add :upload_id, :string
      add :content_length, :integer
      add :content_type, :string
      add :last_modified, :naive_datetime
      add :etag, :string

      timestamps()
    end

    create unique_index(:pending_uploads, [:unique_identifier])
  end
end
