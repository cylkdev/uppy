defmodule LearnElixirPG.Support.Factory.UserAvatar do
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.Schemas.UserAvatar

  @impl FactoryEx
  def repo, do: LearnElixirPG.Repo

  @impl FactoryEx
  def build(args \\ %{}) do
    Map.merge(
      %{
        name: "#{Faker.Cat.name()}_#{FactoryEx.SchemaCounter.next("user_avatars_name")}"
      },
      args
    )
  end
end
