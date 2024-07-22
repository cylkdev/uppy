defmodule Uppy.Support.Factory.Objects.UserAvatarObject do
  @moduledoc false
  @behaviour FactoryEx

  @impl FactoryEx
  def schema, do: Uppy.Support.PG.Objects.UserAvatarObject

  @impl FactoryEx
  def repo, do: Uppy.Support.Repo

  @impl FactoryEx
  def build(attrs \\ %{}) do
    Map.merge(%{}, attrs)
  end
end
