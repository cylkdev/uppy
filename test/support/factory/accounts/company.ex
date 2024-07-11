defmodule Uppy.Support.Factory.Accounts.Company do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.PG.Accounts.Company

  @impl FactoryEx
  def repo, do: Uppy.Support.Repo

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
