defmodule Uppy.Repo.Migrations.CreateUserAvatarFileInfos do
  use Ecto.Migration

  def change do
    create table(:user_avatar_file_infos) do
      add :assoc_id, references(:user_avatars, on_update: :update_all)

      add :state, :text, null: false

      add :key, :text, null: false
      add :upload_id, :text

      add :content_length, :integer
      add :content_type, :text
      add :e_tag, :text
      add :last_modified, :naive_datetime

      timestamps()
    end
  end
end
