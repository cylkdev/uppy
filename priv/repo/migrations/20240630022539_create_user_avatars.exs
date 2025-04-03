defmodule Uppy.Support.Repo.Migrations.CreateUserAvatars do
  use Ecto.Migration

  def change do
    create table(:user_avatars) do
      add :name, :text

      timestamps()
    end
  end
end
