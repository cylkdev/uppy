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

  @default_db_action_adapter Uppy.CommonRepoActions

  @callback update_all(
              query :: query(),
              params :: map(),
              updates :: list(),
              opts :: opts()
            ) :: {non_neg_integer(), nil | list()}

  @doc """
  Calculate the given aggregate over the given field.
  """
  @callback aggregate(
              query :: query(),
              params :: map(),
              aggregate :: :avg | :count | :max | :min | :sum,
              field :: atom(),
              opts :: opts()
            ) :: list(schema_data())

  @doc """
  Returns a list of database records.
  """
  @callback all(
              query :: query(),
              opts :: opts()
            ) :: list(schema_data())

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

  def update_all(query, params, updates, opts) do
    adapter!(opts).update_all(query, params, updates, opts)
  end

  def aggregate(query, params, aggregate, field, opts) do
    adapter!(opts).aggregate(query, params, aggregate, field, opts)
  end

  def all(query, opts) do
    adapter!(opts).all(query, opts)
  end

  def all(query, params, opts) do
    adapter!(opts).all(query, params, opts)
  end

  def create(query, params, opts) do
    adapter!(opts).create(query, params, opts)
  end

  def find(query, params, opts) do
    adapter!(opts).find(query, params, opts)
  end

  def update(query, id_or_struct, params, opts) do
    adapter!(opts).update(query, id_or_struct, params, opts)
  end

  def delete(struct, opts) do
    adapter!(opts).delete(struct, opts)
  end

  def delete(query, id, opts) do
    adapter!(opts).delete(query, id, opts)
  end

  def transaction(func, opts) do
    case adapter!(opts).transaction(func, opts) do
      {:ok, {:ok, _} = ok} -> ok
      {:ok, {:error, _} = e} -> e
      res -> res
    end
  end

  defp adapter!(opts) do
    opts[:db_action_adapter] || Config.db_action_adapter() || @default_db_action_adapter
  end
end
