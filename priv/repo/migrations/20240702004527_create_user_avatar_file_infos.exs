defmodule Uppy.Support.Repo.Migrations.CreateUserAvatarFileInfos do
  use Ecto.Migration

  def change do
    create table(:user_avatar_file_infos) do
      add :assoc_id, references(:user_avatars, on_update: :update_all)

      add :state, :string, null: false
      add :unique_identifier, :string
      add :filename, :string, null: false
      add :key, :string, null: false
      add :upload_id, :string
      add :content_length, :bigint
      add :content_type, :string
      add :e_tag, :string
      add :last_modified, :naive_datetime

      timestamps()
    end
  end
end
