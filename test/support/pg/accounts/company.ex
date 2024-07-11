defmodule Uppy.Support.PG.Accounts.Company do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "companies" do
    field :name, :string

    has_many :users, Uppy.Support.PG.Accounts.User

    timestamps()
  end

  @allowed_fields [
    :name
  ]

  @doc false
  def changeset(model_or_changeset, attrs) do
    cast(model_or_changeset, attrs, @allowed_fields)
  end
end
