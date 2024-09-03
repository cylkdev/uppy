defmodule Uppy.Support.Factory.Accounts.UserAvatar do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.PG.Accounts.UserAvatar

  @impl FactoryEx
  def repo, do: Uppy.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(
      %{
        display_name: Faker.Internet.user_name()
      },
      attrs
    )
  end
end
