defmodule Uppy.Actions do
  alias Uppy.Adapter.Action

  @type t_res(t) :: Action.t_res(t)

  @type adapter :: Action.adapter()
  @type id :: Action.id()
  @type schema :: Action.schema()
  @type schema_data :: Action.schema_data()
  @type params :: Action.params()
  @type options :: Action.options()

  @spec create(
          adapter :: adapter(),
          schema :: schema(),
          params :: params(),
          options :: options()
        ) :: t_res(schema_data())
  def create(adapter, schema, params, options) do
    adapter.create(schema, params, options)
  end

  @spec find(
          adapter :: adapter(),
          schema :: schema(),
          params :: params(),
          options :: options()
        ) :: t_res(schema_data())
  def find(adapter, schema, params, options) do
    adapter.find(schema, params, options)
  end

  @spec update(
          adapter :: adapter(),
          schema :: schema(),
          schema_data :: schema_data(),
          params :: params,
          options :: options()
        ) :: t_res(schema_data())
  def update(adapter, schema, %_{} = schema_data, params, options) do
    adapter.update(schema, schema_data, params, options)
  end

  @spec update(
          adapter :: adapter(),
          schema :: schema(),
          id :: id(),
          params :: params(),
          options :: options()
        ) :: t_res(schema_data())
  def update(adapter, schema, id, params, options) do
    adapter.update(schema, id, params, options)
  end

  @spec delete(
          adapter :: adapter(),
          schema :: schema(),
          id :: id(),
          options :: options()
        ) :: t_res(schema_data())
  def delete(adapter, schema, id, options) do
    adapter.delete(schema, id, options)
  end

  @spec delete(
          adapter :: adapter(),
          schema_data :: struct(),
          options :: options()
        ) :: t_res(schema_data())
  def delete(adapter, schema_data, options) do
    adapter.delete(schema_data, options)
  end

  @spec transaction(
          adapter :: adapter(),
          func :: function(),
          options :: options()
        ) :: t_res(schema_data())
  def transaction(adapter, func, options) do
    adapter.transaction(func, options)
  end
end
