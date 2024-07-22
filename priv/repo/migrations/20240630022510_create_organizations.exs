defmodule Uppy.Support.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :name, :text

      timestamps()
    end
  end
end
