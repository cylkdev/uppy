defmodule Uppy.Support.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles) do
      add :display_name, :text
      add :user_id, references(:users)

      timestamps()
    end
  end
end
