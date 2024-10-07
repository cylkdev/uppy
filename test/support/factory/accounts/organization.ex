defmodule Uppy.Support.Factory.Accounts.Organization do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.Schemas.Accounts.Organization

  @impl FactoryEx
  def repo, do: Uppy.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(
      %{
        name: Faker.Company.name()
      },
      attrs
    )
  end
end
