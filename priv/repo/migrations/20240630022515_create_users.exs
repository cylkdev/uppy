defmodule Uppy.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :text
      add :organization_id, references(:organizations)

      timestamps()
    end
  end
end
