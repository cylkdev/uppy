defmodule Uppy.Support.Factory.Objects.UserAvatarObject do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.PG.Objects.UserAvatarObject

  @impl FactoryEx
  def repo, do: Uppy.Support.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(
      %{
        filename: "image.jpeg",
        unique_identifier: Faker.UUID.v4(),
        content_length: 123_456,
        content_type: "image/jpeg",
        last_modified: ~U[2000-01-01 00:00:00Z],
        archived: false
      },
      attrs
    )
  end
end
