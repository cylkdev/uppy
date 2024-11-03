defmodule Uppy.Schemas.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "users" do
    field :email, :string

    # belongs_to :organization, Uppy.Schemas.Organization

    timestamps()
  end

  @required_fields []
  @allowed_fields [:email] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
  end
end
