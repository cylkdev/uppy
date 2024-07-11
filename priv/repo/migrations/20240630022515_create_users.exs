defmodule Uppy.Support.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :text
      add :company_id, references(:companies)

      timestamps()
    end
  end
end
