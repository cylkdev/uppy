defmodule Uppy.Repo.Migrations.CreateUserAvatarFileInfos do
  use Ecto.Migration

  def change do
    create table(:user_avatar_file_infos) do
      add :e_tag, :text
      add :content_length, :integer
      add :content_type, :text
      add :key, :text, null: false
      add :last_modified, :naive_datetime
      add :status, :text, null: false
      add :upload_id, :text

      add :filename, :text
      add :unique_identifier, :text

      add :assoc_id, references(:user_avatars,
        on_update: :update_all
      )

      add :user_id, references(:users,
        on_update: :update_all
      )

      timestamps()
    end
  end
end
