defmodule Uppy.Phases.HolderDataloader do
  @moduledoc """
  Loads the holder association of the schema data if the `holder` is nil.
  """
  alias Uppy.{Action, Utils}

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.HolderDataloader"

  @impl Uppy.Adapter.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipeline.Input{
          schema: schema,
          value: %{schema_data: schema_data} = value,
          options: runtime_options
        } = input,
        phase_options
      ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN", binding: binding())

    options = Keyword.merge(phase_options, runtime_options)

    case Map.get(value, :holder) do
      nil ->
        with {:ok, holder} <- find_holder(schema, schema_data, options) do
          {:ok, %{input | value: Map.put(value, :holder, holder)}}
        end

      _ ->
        {:ok, input}
    end
  end

  @doc """
  Fetches the holder association record.

  ## Options

      * `:holder_association_source` - The name of the field for the holder association. This should be an
        association that the `schema` belongs to.

      * `:holder_primary_key_source` The name of the primary key field on the holder schema data, for eg. `:id`.

  ### Examples

      iex> Uppy.Phases.HolderDataloader.find_holder(YourSchema, %YourSchema{id: 1}, holder_primary_key_source: :id)
      iex> Uppy.Phases.HolderDataloader.find_holder(YourSchema, %YourSchema{id: 1}, holder_association_source: :user)
      iex> Uppy.Phases.HolderDataloader.find_holder(YourSchema, %YourSchema{id: 1})
      iex> Uppy.Phases.HolderDataloader.find_holder(YourSchema, %{id: 1})
  """
  @spec find_holder(schema(), schema_data(), options()) :: t_res(schema_data())
  def find_holder(schema, %_{} = schema_data, options) do
    Utils.Logger.debug(@logger_prefix, "find_holder BEGIN", binding: binding())

    assoc_source = Keyword.get(options, :holder_association_source, :user)
    ecto_assoc = fetch_ecto_association!(schema, assoc_source)

    holder_schema = ecto_assoc.queryable
    holder_owner_key = ecto_assoc.owner_key
    holder_primary_key = Keyword.get(options, :holder_primary_key_source, ecto_assoc.related_key)

    holder_id = Map.fetch!(schema_data, holder_owner_key)

    params = %{holder_primary_key => holder_id}

    Utils.Logger.debug(@logger_prefix, "fetching schema data holder")

    Utils.Logger.debug(
      @logger_prefix,
      "schema=#{inspect(holder_schema)}, owner_key=#{inspect(holder_owner_key)}, primary_key=#{inspect(holder_primary_key)}, id=#{inspect(holder_id)}"
    )

    Action.find(holder_schema, params, options)
  end

  @spec find_holder(schema(), params(), options()) :: t_res(schema_data())
  def find_holder(schema, params, options) do
    Utils.Logger.debug(@logger_prefix, "find_holder BEGIN", binding: binding())

    with {:ok, schema_data} <- Action.find(schema, params, options) do
      find_holder(schema, schema_data, options)
    end
  end

  @spec find_holder(schema(), params() | schema_data()) :: t_res(schema_data())
  def find_holder(schema, params_or_schema_data) do
    Utils.Logger.debug(@logger_prefix, "find_holder BEGIN", binding: binding())

    find_holder(schema, params_or_schema_data, [])
  end

  defp fetch_ecto_association!(schema, assoc) do
    with nil <- schema.__schema__(:association, assoc) do
      raise "Expected an association for schema #{inspect(schema)}, got: #{inspect(assoc)}"
    end
  end
end
