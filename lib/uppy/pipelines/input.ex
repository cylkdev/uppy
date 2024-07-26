defmodule Uppy.Pipelines.Input do
  alias Uppy.Error

  defstruct [
    :bucket,
    :context,
    :holder,
    :resource_name,
    :options,
    :private,
    :schema,
    :value,
    :source
  ]

  def new!(attrs), do: struct!(__MODULE__, attrs)

  def find_private(input, key) do
    case get_private(input, key) do
      nil -> Error.call(:not_found, "state not found", %{key: key, input: input})
      state -> {:ok, state}
    end
  end

  def put_holder(%{holder: _} = input, value) do
    %{input | holder: value}
  end

  def get_private(%{private: private}, key) do
    Map.get(private, key)
  end

  def put_private(%{private: private} = input, key, value) do
    %{input | private: Map.put(private, key, value)}
  end

  def put_context(input, assigns) when is_list(assigns) do
    put_context(input, Map.new(assigns))
  end

  def put_context(%{context: context} = input, assigns) do
    %{input | context: Map.merge(context, assigns)}
  end

  def put_value(%{value: _} = input, value) do
    %{input | value: value}
  end
end
