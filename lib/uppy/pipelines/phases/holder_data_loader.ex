defmodule Uppy.Pipeline.Phases.HolderDataLoader do
  @moduledoc """
  Loads the holder association of the schema data if the `holder` is nil.
  """
  alias Uppy.Pipelines.Input
  alias Uppy.{Actions, Utils}

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipeline.Phases.HolderDataLoader"

  @impl Uppy.Adapter.Pipeline.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Pipeline.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
    %Uppy.Pipelines.Input{
      holder: nil,
      schema: schema,
      value: schema_data,
      options: runtime_options
    } = input,
    phase_options
  ) do
    Utils.Logger.debug(@logger_prefix, "run schema=#{inspect(schema)}, id=#{inspect(schema_data.id)}")
    Utils.Logger.debug(@logger_prefix, "loading holder")

    options = Keyword.merge(phase_options, runtime_options)

    with {:ok, holder} <- find_holder(schema, schema_data, options) do
      {
        :ok,
        input
        |> Input.put_holder(holder)
        |> maybe_put_private(%{holder: holder}, options)
      }
    end
  end

  @spec run(input(), options()) :: t_res(input())
  def run(%Uppy.Pipelines.Input{holder: _, schema: schema, value: schema_data} = input, _phase_options) do
    Utils.Logger.debug(@logger_prefix, "run schema=#{inspect(schema)}, id=#{inspect(schema_data.id)}")
    Utils.Logger.debug(@logger_prefix, "holder already loaded, skipping execution")

    {:ok, input}
  end

  @doc """
  Fetches the holder association record.

  ## Options

      * `:holder_association_source` - The name of the field for the holder association. This should be an
        association that the `schema` belongs to.

      * `:holder_primary_key_source` The name of the primary key field on the holder schema data, for eg. `:id`.

  ### Examples

      iex> Uppy.Pipeline.Phases.HolderDataLoader.find_holder(YourSchema, %YourSchema{id: 1}, holder_primary_key_source: :id)
      iex> Uppy.Pipeline.Phases.HolderDataLoader.find_holder(YourSchema, %YourSchema{id: 1}, holder_association_source: :user)
      iex> Uppy.Pipeline.Phases.HolderDataLoader.find_holder(YourSchema, %YourSchema{id: 1})
      iex> Uppy.Pipeline.Phases.HolderDataLoader.find_holder(YourSchema, %{id: 1})
  """
  @spec find_holder(schema(), schema_data(), options()) :: t_res(schema_data())
  def find_holder(schema, %_{} = schema_data, options) do
    assoc_source = Keyword.get(options, :holder_association_source, :user)
    ecto_assoc = fetch_ecto_association!(schema, assoc_source)

    holder_schema = ecto_assoc.queryable
    holder_owner_key = ecto_assoc.owner_key
    holder_primary_key = Keyword.get(options, :holder_primary_key_source, ecto_assoc.related_key)

    holder_id = Map.fetch!(schema_data, holder_owner_key)

    params = %{holder_primary_key => holder_id}

    Utils.Logger.debug(@logger_prefix, "fetching schema data holder")
    Utils.Logger.debug(@logger_prefix, "schema=#{inspect(holder_schema)}, owner_key=#{inspect(holder_owner_key)}, primary_key=#{inspect(holder_primary_key)}, id=#{inspect(holder_id)}")

    Actions.find(holder_schema, params, options)
  end

  @spec find_holder(schema(), params(), options()) :: t_res(schema_data())
  def find_holder(schema, params, options) do
    with {:ok, schema_data} <- Actions.find(schema, params, options) do
      find_holder(schema, schema_data, options)
    end
  end

  @spec find_holder(schema(), params() | schema_data()) :: t_res(schema_data())
  def find_holder(schema, params_or_schema_data) do
    find_holder(schema, params_or_schema_data, [])
  end

  defp fetch_ecto_association!(schema, assoc) do
    with nil <- schema.__schema__(:association, assoc) do
      raise "Expected an association for schema #{inspect(schema)}, got: #{inspect(assoc)}"
    end
  end

  defp maybe_put_private(input, payload, options) do
    if options[:cache_pipeline_results?] do
      Input.put_private(input, __MODULE__, payload)
    else
      input
    end
  end
end
