defmodule Uppy.Fixture.User do
  alias Uppy.{
    Repo,
    Schemas.User
  }

  def insert!(params) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert!()
  end
end
