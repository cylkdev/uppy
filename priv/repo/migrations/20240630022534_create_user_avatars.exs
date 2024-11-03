defmodule Uppy.Repo.Migrations.CreateUserAvatars do
  use Ecto.Migration

  def change do
    create table(:user_avatars) do
      add :name, :text
      add :description, :text

      add :user_id, references(:users)

      timestamps()
    end
  end
end
