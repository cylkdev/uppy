defmodule Uppy.Fixture.UserAvatar do
  alias Uppy.{
    Repo,
    Schemas.UserAvatar
  }

  def insert!(params) do
    %UserAvatar{}
    |> UserAvatar.changeset(params)
    |> Repo.insert!()
  end
end
