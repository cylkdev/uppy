defmodule Uppy.EctoHelpers do
  alias Uppy.Error

  def find_ecto_association(
    %Ecto.Query{
      from: %Ecto.Query.FromExpr{
        source: {_source, schema}
      }
    },
    field
  ) do
    find_ecto_association(schema, field)
  end

  def find_ecto_association({_source, schema}, field) do
    find_ecto_association(schema, field)
  end

  def find_ecto_association(schema, field) do
    case schema.__schema__(:association, field) do
      nil -> {:error, Error.not_found("association not found", %{schema: schema, field: field})}
      assoc -> {:ok, assoc}
    end
  end
end
