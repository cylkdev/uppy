defmodule Uppy.Repo.Migrations.CreateUploads do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :unique_identifier, :string
      add :key, :string

      add :content_length, :integer
      add :content_type, :string
      add :last_modified, :naive_datetime
      add :etag, :string

      add :pending_upload_id, references(:pending_uploads, on_delete: :nilify_all)

      timestamps()
    end

    create index(:uploads, [:pending_upload_id])
    create unique_index(:uploads, [:unique_identifier])
  end
end
