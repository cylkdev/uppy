defmodule Uppy.Support.Schemas.Accounts.Organization do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "organizations" do
    field :name, :string

    has_many :users, Uppy.Support.Schemas.Accounts.User

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
