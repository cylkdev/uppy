defmodule Uppy.DBAction do
  @moduledoc """
  ...
  """
  alias Uppy.Config

  @type adapter :: module()
  @type opts :: keyword()
  @type id :: integer() | binary()
  @type query :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()} | Ecto.Query.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @default_action_adapter EctoShorts.Actions

  @doc """
  Returns a list of database records.
  """
  @callback all(
    query :: query(),
    params :: params(),
    opts :: opts()
  ) :: list(schema_data())

  @doc """
  Creates a database record.
  """
  @callback create(
              query :: query(),
              params :: params(),
              opts :: opts()
            ) :: t_res(schema_data())

  @doc """
  Fetches the database record.
  """
  @callback find(
              query :: query(),
              params :: params(),
              opts :: opts()
            ) :: t_res(schema_data())

  @doc """
  Updates the database record.
  """
  @callback update(
              query :: query(),
              id :: id(),
              params :: params(),
              opts :: opts()
            ) :: t_res(schema_data())

  @callback update(
              query :: query(),
              schema_data :: schema_data(),
              params :: params,
              opts :: opts()
            ) :: t_res(schema_data())

  @doc """
  Deletes the record from the database.
  """
  @callback delete(
              query :: query(),
              id :: id(),
              opts :: opts()
            ) :: t_res(schema_data())

  @callback delete(
              schema_data :: struct(),
              opts :: opts()
            ) :: t_res(schema_data())

  @doc """
  Executes the function inside a transaction.
  """
  @callback transaction(func :: function(), opts :: opts()) :: t_res(term())

  def create(schema, params, opts \\ []) do
    adapter!(opts).create(schema, params, opts)
  end

  def find(schema, params, opts \\ []) do
    adapter!(opts).find(schema, params, opts)
  end

  def update(schema, id_or_schema_data, params, opts \\ [])

  def update(schema, %_{} = schema_data, params, opts) do
    adapter!(opts).update(schema, schema_data, params, opts)
  end

  def update(schema, id, params, opts) do
    adapter!(opts).update(schema, id, params, opts)
  end

  def delete(schema, id, opts) do
    adapter!(opts).delete(schema, id, opts)
  end

  def delete(schema_data, opts) do
    adapter!(opts).delete(schema_data, opts)
  end

  def delete(schema_data) do
    delete(schema_data, [])
  end

  def transaction(func, opts \\ []) do
    adapter!(opts).transaction(func, opts)
  end

  defp adapter!(opts) do
    with nil <- opts[:action_adapter],
      nil <- Config.action_adapter() do
      @default_action_adapter
    end
  end
end
