defmodule Uppy.Adapter.Actions do
  @moduledoc """
  An adapter for executing database actions.
  """

  @type adapter :: Uppy.adapter()
  @type id :: Uppy.id()
  @type schema :: Uppy.schema()
  @type schema_data :: Uppy.schema_data()
  @type params :: Uppy.params()
  @type options :: Uppy.options()

  @typedoc "A status tuple response."
  @type t_res(t) :: {:ok, t} | {:error, term()}

  @doc """
  Creates a database record.

  Returns `{:ok, schema_data()}` or `{:error, term()}`.
  """
  @callback create(
              schema :: schema(),
              params :: params(),
              options :: options()
            ) :: t_res(schema_data())

  @doc """
  Fetches a database record.

  Returns `{:ok, schema_data()}` or `{:error, term()}`.
  """
  @callback find(
              schema :: schema(),
              params :: params(),
              options :: options()
            ) :: t_res(schema_data())

  @doc """
  Updates an existing database record.

  Returns `{:ok, schema_data()}` or `{:error, term()}`.
  """
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

  @doc """
  Deletes an existing database record.

  Returns `{:ok, schema_data()}` or `{:error, term()}`.
  """
  @callback delete(
              schema :: schema(),
              id :: id(),
              options :: options()
            ) :: t_res(schema_data())

  @callback delete(
              schema_data :: struct(),
              options :: options()
            ) :: t_res(schema_data())

  @doc """
  Executes a database transaction.

  Returns `{:ok, schema_data()}` or `{:error, term()}`.
  """
  @callback transaction(func :: function(), options :: options()) :: t_res(term())
end
