defmodule Uppy.Adapter.Action do
  @moduledoc """
  An adapter for executing database operations.
  """

  @type adapter :: module()
  @type id :: non_neg_integer() | binary()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @doc """
  Returns a list of database records.
  """
  @callback all(
    query :: query(),
    params :: params(),
    options :: options()
  ) :: list(schema_data())

  @doc """
  Creates a database record.
  """
  @callback create(
    schema :: queryable(),
    params :: params(),
    options :: options()
  ) :: t_res(schema_data())

  @doc """
  Fetches the database record.
  """
  @callback find(
    schema :: queryable(),
    params :: params(),
    options :: options()
  ) :: t_res(schema_data())

  @doc """
  Updates the database record.
  """
  @callback update(
    schema :: queryable(),
    id :: id(),
    params :: params(),
    options :: options()
  ) :: t_res(schema_data())

  @callback update(
    schema :: queryable(),
    schema_data :: schema_data(),
    params :: params,
    options :: options()
  ) :: t_res(schema_data())

  @doc """
  Deletes the record from the database.
  """
  @callback delete(
    schema :: queryable(),
    id :: id(),
    options :: options()
  ) :: t_res(schema_data())

  @callback delete(
    schema_data :: struct(),
    options :: options()
  ) :: t_res(schema_data())

  @doc """
  Executes the function inside a transaction.
  """
  @callback transaction(func :: function(), options :: options()) :: t_res(term())
end
