defmodule Uppy.Repo.Migrations.CreateUploads do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :state, :string, null: false
      add :label, :string
      add :promoted, :boolean, null: false, default: false
      add :unique_identifier, :string
      add :bucket, :string
      add :key, :string, null: false
      add :upload_id, :string
      add :filename, :string
      add :content_length, :bigint
      add :content_type, :string
      add :last_modified, :naive_datetime
      add :etag, :string

      add :parent_id, references(:uploads, on_delete: :nilify_all)

      timestamps()
    end

    create index(:uploads, :parent_id)

    create unique_index(:uploads, [:key])
    create unique_index(:uploads, [:unique_identifier])
  end
end
