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

  def create(attrs) do
    struct!(__MODULE__, attrs)
  end

  def put_holder(%__MODULE__{holder: _} = resolution, value) do
    %{resolution | holder: value}
  end

  def find_private(%__MODULE__{holder: _} = resolution, key) do
    case get_private(resolution, key) do
      nil -> Error.not_found("state not found", %{key: key, resolution: resolution})
      state -> {:ok, state}
    end
  end

  def get_private(%__MODULE__{private: private}, key) do
    Map.get(private, key)
  end

  def put_private(%__MODULE__{private: private} = resolution, key, value) do
    %{resolution | private: Map.put(private, key, value)}
  end

  def put_context(%__MODULE__{} = resolution, assigns) when is_list(assigns) do
    put_context(resolution, Map.new(assigns))
  end

  def put_context(%__MODULE__{context: context} = resolution, assigns) do
    %{resolution | context: Map.merge(context, assigns)}
  end

  def put_value(%__MODULE__{value: _} = resolution, value) do
    %{resolution | value: value}
  end
end
