defmodule Uppy.Support.PG.Accounts.User do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :email, :string

    belongs_to :company, Uppy.Support.PG.Accounts.Company

    timestamps()
  end

  @required_fields [:company_id]
  @allowed_fields [
                    :email
                  ] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
