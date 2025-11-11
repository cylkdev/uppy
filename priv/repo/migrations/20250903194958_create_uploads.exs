defmodule Uppy.Repo.Migrations.CreateUploads do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :state, :string, null: false
      add :request_key, :string, null: false
      add :stored_key, :string, null: false
      add :filename, :string
      add :content_length, :bigint
      add :content_type, :string
      add :last_modified, :naive_datetime
      add :etag, :string

      timestamps()
    end

    create unique_index(:uploads, :request_key)
    create unique_index(:uploads, :stored_key)
  end
end
