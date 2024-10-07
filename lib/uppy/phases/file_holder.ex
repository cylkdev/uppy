defmodule Uppy.Phases.FileHolder do
  @moduledoc """
  Loads the holder association of the schema data if the `holder` is nil.
  """
  alias Uppy.{Action, EctoHelpers, Utils}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.FileHolder"

  @impl Uppy.Phase
  @doc """
  Implementation for `c:Uppy.Phase.run/2`
  """
  def run(resolution, opts \\ [])

  def run(
    %Uppy.Resolution{
      query: query,
      context: context,
      value: schema_data
    } = resolution,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    with {:ok, holder} <- find_holder(query, schema_data, opts) do
      Utils.Logger.debug(@logger_prefix, "run OK")

      {:ok, %{resolution | context: Map.put(context, :holder, holder)}}
    else
      error ->
        Utils.Logger.debug(@logger_prefix, "run ERROR")

        error
    end
  end

  @doc """
  Fetches the holder association record.

  ## Options

      * `:holder_association_source` - The name of the field for the holder association.
        This should be an association that the `schema` belongs to.

      * `:holder_primary_key_source` The name of the primary key field on the holder
        schema data, for eg. `:id`.

  ### Examples

      iex> Uppy.Phases.FileHolder.find_holder(YourSchema, %YourSchema{id: 1}, holder_primary_key_source: :id)

      iex> Uppy.Phases.FileHolder.find_holder(YourSchema, %YourSchema{id: 1}, holder_association_source: :user)

      iex> Uppy.Phases.FileHolder.find_holder(YourSchema, %YourSchema{id: 1})

      iex> Uppy.Phases.FileHolder.find_holder(YourSchema, %{id: 1})
  """
  def find_holder(query, find_params_or_schema_data, opts \\ [])

  def find_holder(query, %_{} = schema_data, opts) do
    assoc_source = Keyword.get(opts, :holder_association_source, :user)

    with {:ok, ecto_assoc} <- EctoHelpers.find_ecto_association(query, assoc_source) do
      schema = ecto_assoc.queryable
      owner_key = ecto_assoc.owner_key
      primary_key = Keyword.get(opts, :holder_primary_key_source, ecto_assoc.related_key)

      id = Map.fetch!(schema_data, owner_key)

      Action.find(schema, %{primary_key => id}, opts)
    end
  end

  def find_holder(schema, params, opts) do
    with {:ok, schema_data} <- Action.find(schema, params, opts) do
      find_holder(schema, schema_data, opts)
    end
  end
end
