defmodule Uppy.Support.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :text

      timestamps()
    end
  end
end
