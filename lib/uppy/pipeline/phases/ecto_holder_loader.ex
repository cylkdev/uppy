defmodule Uppy.Pipeline.Phases.EctoHolderLoader do
  alias Uppy.Actions

  def run(input, options) do
    with {:ok, holder} <-
           find_holder_by_association(
             input.context.action_adapter,
             input.context.schema,
             input.value,
             options
           ) do
      {:ok, Map.put(input, :holder, holder)}
    end
  end

  def find_holder_by_association(action_adapter, schema, schema_data, options) do
    assoc = Keyword.get(options, :association, :user)

    ecto_association = fetch_ecto_association!(schema, assoc)

    holder_schema = ecto_association.queryable
    holder_owner_key = ecto_association.owner_key
    holder_primary_key = Keyword.get(options, :primary_key, ecto_association.related_key)

    Actions.find(
      action_adapter,
      holder_schema,
      %{holder_primary_key => Map.fetch!(schema_data, holder_owner_key)},
      options
    )
  end

  defp fetch_ecto_association!(schema, assoc) do
    with nil <- schema.__schema__(:association, assoc) do
      raise "Expected an association for schema #{inspect(schema)}, got: #{inspect(assoc)}"
    end
  end
end
