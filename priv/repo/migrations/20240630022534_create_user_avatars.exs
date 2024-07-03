defmodule Uppy.Support.Repo.Migrations.CreateUserAvatars do
  use Ecto.Migration

  def change do
    create table(:user_avatars) do
      add :name, :text
      add :description, :text
      add :user_profile_id, references(:user_profiles)

      timestamps()
    end
  end
end
