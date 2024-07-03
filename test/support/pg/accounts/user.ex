defmodule Uppy.Support.PG.Accounts.User do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :email, :string

    timestamps()
  end

  @allowed_fields [
    :email
  ]

  @doc false
  def changeset(model_or_changeset, attrs) do
    cast(model_or_changeset, attrs, @allowed_fields)
  end
end
