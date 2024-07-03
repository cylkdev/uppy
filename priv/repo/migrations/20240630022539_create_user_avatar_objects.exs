defmodule Uppy.Support.Repo.Migrations.CreateUserAvatarObjects do
  use Ecto.Migration

  def change do
    create table(:user_avatar_objects) do
      add :user_avatar_id, references(:user_avatars,
        on_delete: :restrict,
        on_update: :update_all
      ), null: false

      add :archived, :boolean, null: false, default: false
      add :archived_at, :utc_datetime
      add :content_length, :integer
      add :content_type, :text
      add :e_tag, :text
      add :filename, :text, null: false
      add :key, :text, null: false
      add :last_modified, :utc_datetime
      add :upload_id, :text
      add :unique_identifier, :text, null: false

      add :user_id, references(:users,
        on_delete: :nilify_all,
        on_update: :update_all
      )

      timestamps()
    end

    create index(:user_avatar_objects, [:user_id, :user_avatar_id])
    create index(:user_avatar_objects, [:user_id, :archived])
    create index(:user_avatar_objects, [:user_id, :key])
    create index(:user_avatar_objects, :user_id)
    create unique_index(:user_avatar_objects, [:key, :upload_id])
    create unique_index(:user_avatar_objects, :user_avatar_id)
    create unique_index(:user_avatar_objects, :unique_identifier)
    create unique_index(:user_avatar_objects, :key)
  end
end
