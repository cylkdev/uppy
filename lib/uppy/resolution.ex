defmodule Uppy.Resolution do
  @moduledoc """

    * `bucket` -
    * `context` -
    * `query` -
    * `private` -
    * `resource` -
    * `state` -
    * `value` -
  """

  @enforce_keys [
    :bucket,
    :resource,
    :query,
    :value
  ]

  defstruct @enforce_keys ++ [
    state: :unresolved,
    context: %{},
    private: %{}
  ]

  @type t :: %__MODULE__{
    state: :unresolved | :resolved,
    resource: binary(),
    private: %{optional(atom()) => term()},
    query: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()} | Ecto.Query.t(),
    value: Ecto.Schema.t()
  }

  def resolve(%__MODULE__{} = resolution) do
    %{resolution | state: :resolved}
  end

  def put_result(%__MODULE__{} = resolution, value) do
    %{resolution | state: :resolved, value: value}
  end

  def find_private(%__MODULE__{private: private}, key) do
    case Map.get(private, key) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  def put_private(%__MODULE__{private: private} = resolution, key, value) do
    %{resolution | private: Map.put(private, key, value)}
  end
end
