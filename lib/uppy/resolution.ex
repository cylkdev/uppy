defmodule Uppy.Resolution do
  @moduledoc """
  ...
  """

  defstruct [
    :bucket,
    :query,
    :value,
    context: %{},
    errors: [],
    private: %{},
    state: :unresolved
  ]

  @type t :: %__MODULE__{}

  def put_result(%{state: _, value: _} = resolution, value) do
    %{
      resolution |
      state: :resolved,
      value: value
    }
  end

  def assign_context(%{context: context} = resolution, key, value) do
    %{
      resolution |
      context: Map.put(context, key, value)
    }
  end

  def assign_context(%{context: context} = resolution, assigns) do
    %{
      resolution |
      context: Map.merge(context, assigns)
    }
  end

  def get_private(%{private: private}, key) do
    Map.get(private, key)
  end

  def put_private(%{private: private} = resolution, key, value) do
    %{
      resolution |
      private: Map.put(private, key, value)
    }
  end
end
