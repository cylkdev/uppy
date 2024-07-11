defmodule Uppy.Adapter.Action do
  @type adapter :: module()
  @type id :: term()
  @type schema :: module()
  @type schema_data :: struct()
  @type params :: map()
  @type options :: Keyword.t()

  @type t_res(t) :: {:ok, t} | {:error, term}

  @callback create(
              schema :: schema(),
              params :: params(),
              options :: options()
            ) :: t_res(schema_data())

  @callback find(
              schema :: schema(),
              params :: params(),
              options :: options()
            ) :: t_res(schema_data())

  @callback update(
              schema :: schema(),
              id :: id(),
              params :: params(),
              options :: options()
            ) :: t_res(schema_data())

  @callback update(
              schema :: schema(),
              schema_data :: schema_data(),
              params :: params,
              options :: options()
            ) :: t_res(schema_data())

  @callback delete(
              schema :: schema(),
              id :: id(),
              options :: options()
            ) :: t_res(schema_data())

  @callback delete(
              schema_data :: struct(),
              options :: options()
            ) :: t_res(schema_data())

  @callback transaction(
              func :: function(),
              options :: options()
            ) :: t_res(schema_data())
end
