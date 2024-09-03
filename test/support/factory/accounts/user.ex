defmodule Uppy.Support.Factory.Accounts.User do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.PG.Accounts.User

  @impl FactoryEx
  def repo, do: Uppy.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(
      %{
        email: Faker.Internet.email()
      },
      attrs
    )
  end
end
